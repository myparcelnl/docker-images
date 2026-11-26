<?php

declare(strict_types=1);

namespace MyParcelNL\DevSeed\Setup\Patch\Data;

use Magento\Framework\App\Config\Storage\WriterInterface;
use Magento\Framework\Setup\Patch\DataPatchInterface;
use Magento\Store\Api\StoreRepositoryInterface;
use Magento\Store\Api\WebsiteRepositoryInterface;
use Magento\Store\Model\ScopeInterface;
use Magento\Tax\Api\Data\TaxRateInterfaceFactory;
use Magento\Tax\Api\Data\TaxRuleInterfaceFactory;
use Magento\Tax\Api\TaxRateRepositoryInterface;
use Magento\Tax\Api\TaxRuleRepositoryInterface;
use Magento\Tax\Model\Calculation\RateFactory;
use Magento\Tax\Model\ClassModel;
use Magento\Tax\Model\ResourceModel\Calculation\Rule\CollectionFactory as TaxRuleCollectionFactory;
use Magento\Tax\Model\ResourceModel\TaxClass\CollectionFactory as TaxClassCollectionFactory;

/**
 * Sets the store config: country, locale and tax per website, and shipping, payment and MyParcel
 * values on default scope, also the PostNL mailbox and digital stamp that the seed orders use.
 * Prices include tax (21 % NL and BE, 22 % IT) and cross-border trade is on, so a product has
 * the same price in each country.
 */
class ConfigureStores implements DataPatchInterface
{
    public const TAX_RULE_CODE = 'VAT NL BE IT';

    /** Website code => country, locale, VAT rate. */
    private const WEBSITES = [
        'nl' => ['country' => 'NL', 'locale' => 'nl_NL', 'vat' => 21.0],
        'be' => ['country' => 'BE', 'locale' => 'nl_NL', 'vat' => 21.0],
        'it' => ['country' => 'IT', 'locale' => 'it_IT', 'vat' => 22.0],
    ];

    /** Store view code => locale, where it differs from its website. */
    private const STORE_LOCALES = ['be_fr' => 'fr_FR'];

    private const DEFAULT_CONFIG = [
        'general/country/default'                      => 'NL',
        'general/locale/weight_unit'                   => 'kgs',
        'shipping/origin/country_id'                   => 'NL',
        'tax/calculation/price_includes_tax'           => '1',
        'tax/calculation/shipping_includes_tax'        => '1',
        'tax/calculation/cross_border_trade_enabled'   => '1',
        'tax/defaults/country'                         => 'NL',
        'tax/display/type'                             => '2',
        'tax/display/shipping'                         => '2',
        'tax/cart_display/price'                       => '2',
        'tax/cart_display/subtotal'                    => '2',
        'tax/cart_display/shipping'                    => '2',
        'tax/sales_display/price'                      => '2',
        'tax/sales_display/subtotal'                   => '2',
        'tax/sales_display/shipping'                   => '2',
        'carriers/flatrate/active'                     => '1',
        'carriers/freeshipping/active'                 => '1',
        'carriers/freeshipping/free_shipping_subtotal' => '100',
        'carriers/freeshipping/tax_including'          => '1',
        'payment/checkmo/active'                       => '1',
        'payment/banktransfer/active'                  => '1',
        'payment/cashondelivery/active'                => '1',
        'carriers/myparcel/shipping_cost'              => '24.95',
        // The seed orders use these package types, so the checkout must offer them too
        'myparcelnl_magento_postnl_settings/mailbox/active'       => '1',
        'myparcelnl_magento_postnl_settings/digital_stamp/active' => '1',
    ];

    public function __construct(
        private readonly WriterInterface $configWriter,
        private readonly WebsiteRepositoryInterface $websiteRepository,
        private readonly StoreRepositoryInterface $storeRepository,
        private readonly RateFactory $rateFactory,
        private readonly TaxRateInterfaceFactory $taxRateFactory,
        private readonly TaxRateRepositoryInterface $taxRateRepository,
        private readonly TaxRuleInterfaceFactory $taxRuleFactory,
        private readonly TaxRuleRepositoryInterface $taxRuleRepository,
        private readonly TaxRuleCollectionFactory $taxRuleCollectionFactory,
        private readonly TaxClassCollectionFactory $taxClassCollectionFactory
    ) {
    }

    public static function getDependencies(): array
    {
        return [CreateWebsites::class];
    }

    public function getAliases(): array
    {
        return [];
    }

    public function apply(): self
    {
        foreach (self::DEFAULT_CONFIG as $path => $value) {
            $this->configWriter->save($path, $value);
        }

        foreach (self::WEBSITES as $code => $settings) {
            $websiteId = (int) $this->websiteRepository->get($code)->getId();
            $this->saveForWebsite('general/country/default', $settings['country'], $websiteId);
            $this->saveForWebsite('general/locale/code', $settings['locale'], $websiteId);
            $this->saveForWebsite('tax/defaults/country', $settings['country'], $websiteId);
        }

        foreach (self::STORE_LOCALES as $code => $locale) {
            $storeId = (int) $this->storeRepository->get($code)->getId();
            $this->configWriter->save('general/locale/code', $locale, ScopeInterface::SCOPE_STORES, $storeId);
        }

        $this->createTaxRule();

        return $this;
    }

    private function saveForWebsite(string $path, string $value, int $websiteId): void
    {
        $this->configWriter->save($path, $value, ScopeInterface::SCOPE_WEBSITES, $websiteId);
    }

    private function createTaxRule(): void
    {
        $rateIds = [];
        foreach (self::WEBSITES as $settings) {
            $rateIds[] = $this->taxRateId($settings['country'], $settings['vat']);
        }

        $existing = $this->taxRuleCollectionFactory->create()->addFieldToFilter('code', self::TAX_RULE_CODE);
        if ($existing->getSize()) {
            return;
        }

        $rule = $this->taxRuleFactory->create();
        $rule->setCode(self::TAX_RULE_CODE)
            ->setPriority(0)
            ->setPosition(0)
            ->setCustomerTaxClassIds([$this->taxClassId('Retail Customer', ClassModel::TAX_CLASS_TYPE_CUSTOMER)])
            ->setProductTaxClassIds([$this->taxClassId('Taxable Goods', ClassModel::TAX_CLASS_TYPE_PRODUCT)])
            ->setTaxRateIds(array_values(array_unique($rateIds)));
        $this->taxRuleRepository->save($rule);
    }

    private function taxRateId(string $country, float $rate): int
    {
        $code = 'VAT ' . $country;

        $existing = $this->rateFactory->create()->loadByCode($code);
        if ($existing->getId()) {
            return (int) $existing->getId();
        }

        $taxRate = $this->taxRateFactory->create();
        $taxRate->setCode($code)
            ->setTaxCountryId($country)
            ->setTaxRegionId(0)
            ->setTaxPostcode('*')
            ->setRate($rate);

        return (int) $this->taxRateRepository->save($taxRate)->getId();
    }

    /** Tax classes that setup:install creates. */
    private function taxClassId(string $name, string $type): int
    {
        $id = (int) $this->taxClassCollectionFactory->create()
            ->addFieldToFilter('class_name', $name)
            ->addFieldToFilter('class_type', $type)
            ->getFirstItem()
            ->getId();

        if (! $id) {
            throw new \RuntimeException(sprintf('Tax class "%s" (%s) does not exist', $name, $type));
        }

        return $id;
    }
}
