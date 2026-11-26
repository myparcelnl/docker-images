<?php

declare(strict_types=1);

namespace MyParcelNL\DevSeed\Model;

use Magento\Catalog\Api\ProductRepositoryInterface;
use Magento\Customer\Api\CustomerRepositoryInterface;
use Magento\Framework\App\Area;
use Magento\Framework\App\Config\ScopeConfigInterface;
use Magento\Framework\App\ResourceConnection;
use Magento\Framework\DataObject;
use Magento\Quote\Api\CartManagementInterface;
use Magento\Quote\Api\CartRepositoryInterface;
use Magento\Quote\Model\Quote;
use Magento\Quote\Model\Quote\Address\RateFactory;
use Magento\Quote\Model\QuoteFactory;
use Magento\Sales\Api\InvoiceOrderInterface;
use Magento\Sales\Api\ShipOrderInterface;
use Magento\Store\Api\StoreRepositoryInterface;
use Magento\Store\Model\App\Emulation;
use Magento\Store\Model\ScopeInterface;

/**
 * Places one planned order (see OrderPlanner) through Magento's quote and order services, as a checkout does.
 * Invoices processing and complete orders, ships complete ones, then moves all dates to the planned created_at.
 * Run it in the frontend area. It sends no email.
 */
class OrderCreator
{
    private const METHODS = [
        'myparcel'     => 'myparcel_myparcel',
        'flatrate'     => 'flatrate_flatrate',
        'freeshipping' => 'freeshipping_freeshipping',
    ];

    /** MyParcel orders that got the rate from the seed, because the carrier returned none. */
    private int $fallbackRates = 0;

    /** @var array<string, array<string, mixed>>|null */
    private ?array $addresses = null;

    public function __construct(
        private readonly Fixtures $fixtures,
        private readonly RegionResolver $regionResolver,
        private readonly StoreRepositoryInterface $storeRepository,
        private readonly Emulation $emulation,
        private readonly QuoteFactory $quoteFactory,
        private readonly CartRepositoryInterface $cartRepository,
        private readonly CartManagementInterface $cartManagement,
        private readonly CustomerRepositoryInterface $customerRepository,
        private readonly ProductRepositoryInterface $productRepository,
        private readonly RateFactory $rateFactory,
        private readonly ScopeConfigInterface $scopeConfig,
        private readonly InvoiceOrderInterface $invoiceOrder,
        private readonly ShipOrderInterface $shipOrder,
        private readonly ResourceConnection $resource,
        private readonly SeedOrderContext $context
    ) {
    }

    /** @param array<string, mixed> $spec one entry of OrderPlanner::plan() */
    public function create(array $spec): int
    {
        $store = $this->storeRepository->get($spec['store_code']);

        $this->emulation->startEnvironmentEmulation((int) $store->getId(), Area::AREA_FRONTEND, true);
        try {
            $quoteId = (int) $this->prepareQuote($spec, $store)->getId();
            $orderId = (int) $this->context->run(fn () => $this->cartManagement->placeOrder($quoteId));
        } finally {
            $this->emulation->stopEnvironmentEmulation();
        }

        if (in_array($spec['status'], ['processing', 'complete'], true)) {
            $this->invoiceOrder->execute($orderId);
        }
        if ($spec['status'] === 'complete') {
            $this->shipOrder->execute($orderId);
        }

        $this->moveDates($orderId, $spec['created_at']);

        return $orderId;
    }

    public function fallbackRates(): int
    {
        return $this->fallbackRates;
    }

    private function prepareQuote(array $spec, $store): Quote
    {
        $storeId = (int) $store->getId();
        $quote   = $this->quoteFactory->create();
        $quote->setStore($store);

        if ($spec['customer_email'] !== null) {
            $customer = $this->customerRepository->get($spec['customer_email'], (int) $store->getWebsiteId());
            $quote->assignCustomer($customer);
            $name = ['firstname' => $customer->getFirstname(), 'lastname' => $customer->getLastname(), 'email' => $customer->getEmail()];
        } else {
            $name = $spec['guest'];
            $quote->setCheckoutMethod(CartManagementInterface::METHOD_GUEST)
                ->setCustomerIsGuest(true)
                ->setCustomerEmail($name['email'])
                ->setCustomerFirstname($name['firstname'])
                ->setCustomerLastname($name['lastname']);
        }

        foreach ($spec['items'] as [$sku, $qty]) {
            // addProduct() returns an error message instead of throwing
            $item = $quote->addProduct($this->productRepository->get($sku, false, $storeId), new DataObject(['qty' => $qty]));
            if (is_string($item)) {
                throw new \RuntimeException(sprintf('Cannot add %s: %s', $sku, $item));
            }
        }

        $address = $this->addressData($spec['address_id'], $name);
        $quote->getBillingAddress()->addData($address);
        $quote->getShippingAddress()->addData($address + ['same_as_billing' => 1]);

        if ($spec['delivery_options'] !== null) {
            $quote->setData('myparcel_delivery_options', json_encode($spec['delivery_options'], JSON_THROW_ON_ERROR));
        }

        $this->selectShippingMethod($quote, self::METHODS[$spec['shipping']], $storeId);

        // getPayment() needs a quote ID
        $this->cartRepository->save($quote);
        $quote->setInventoryProcessed(false);
        $quote->getPayment()->importData(['method' => $spec['payment']]);
        $quote->setTotalsCollectedFlag(false)->collectTotals();
        $this->cartRepository->save($quote);

        return $quote;
    }

    private function selectShippingMethod(Quote $quote, string $method, int $storeId): void
    {
        $shipping = $quote->getShippingAddress();
        $shipping->setCollectShippingRates(true);
        $quote->collectTotals();
        $shipping->setShippingMethod($method);

        if ($shipping->getShippingRateByCode($method)) {
            return;
        }

        if ($method !== self::METHODS['myparcel']) {
            throw new \RuntimeException(sprintf('Shipping method %s has no rate', $method));
        }

        // the MyParcel carrier returned no rate: use the configured shipping cost
        $rate = $this->rateFactory->create()
            ->setCode($method)
            ->setCarrier('myparcel')
            ->setCarrierTitle('MyParcel')
            ->setMethod('myparcel')
            ->setMethodTitle('MyParcel')
            ->setPrice((float) $this->scopeConfig->getValue('carriers/myparcel/shipping_cost', ScopeInterface::SCOPE_STORE, $storeId));
        $shipping->addShippingRate($rate)->setCollectShippingRates(false);
        $this->fallbackRates++;
    }

    /** @param array{firstname: string, lastname: string, email: string} $name */
    private function addressData(string $addressId, array $name): array
    {
        $this->addresses ??= array_column($this->fixtures->addresses(), null, 'id');
        $fixture = $this->addresses[$addressId] ?? throw new \RuntimeException("Unknown address $addressId");

        $data = $name + [
            'company'              => $fixture['label'],
            'street'               => [...$fixture['street'], $fixture['house_number']],
            'postcode'             => $fixture['postcode'],
            'city'                 => $fixture['city'],
            'country_id'           => $fixture['country'],
            'telephone'            => $fixture['telephone'],
            'save_in_address_book' => 0,
            // assignCustomer() copied the default address of the customer: clear what this address does not set
            'customer_address_id'  => null,
            'region_id'            => null,
            'region'               => null,
        ];

        $region = $this->regionResolver->resolve($fixture);
        if ($region !== null) {
            $data['region_id'] = (int) $region->getId();
            $data['region']    = $region->getName();
        }

        return $data;
    }

    /** Magento sets created_at on save; the grids copy it, so update them too. */
    private function moveDates(int $orderId, string $createdAt): void
    {
        $connection = $this->resource->getConnection();
        $dates      = ['created_at' => $createdAt, 'updated_at' => $createdAt];

        $connection->update($this->resource->getTableName('sales_order'), $dates, ['entity_id = ?' => $orderId]);
        $connection->update($this->resource->getTableName('sales_order_grid'), $dates, ['entity_id = ?' => $orderId]);
        $connection->update($this->resource->getTableName('sales_order_status_history'), ['created_at' => $createdAt], ['parent_id = ?' => $orderId]);

        foreach (['sales_invoice', 'sales_shipment'] as $table) {
            $connection->update($this->resource->getTableName($table), $dates, ['order_id = ?' => $orderId]);
            $connection->update(
                $this->resource->getTableName($table . '_grid'),
                $dates + ['order_created_at' => $createdAt],
                ['order_id = ?' => $orderId]
            );
        }
    }
}
