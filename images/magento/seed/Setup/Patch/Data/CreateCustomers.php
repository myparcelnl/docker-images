<?php

declare(strict_types=1);

namespace MyParcelNL\DevSeed\Setup\Patch\Data;

use Magento\Customer\Api\CustomerRepositoryInterface;
use Magento\Customer\Api\Data\AddressInterface;
use Magento\Customer\Api\Data\AddressInterfaceFactory;
use Magento\Customer\Api\Data\CustomerInterfaceFactory;
use Magento\Customer\Api\Data\RegionInterfaceFactory;
use Magento\Customer\Api\GroupManagementInterface;
use Magento\Framework\App\Area;
use Magento\Framework\App\State;
use Magento\Framework\Encryption\EncryptorInterface;
use Magento\Framework\Exception\NoSuchEntityException;
use Magento\Framework\Setup\Patch\DataPatchInterface;
use Magento\Store\Api\GroupRepositoryInterface;
use Magento\Store\Api\WebsiteRepositoryInterface;
use MyParcelNL\DevSeed\Model\Fixtures;
use MyParcelNL\DevSeed\Model\RegionResolver;

/**
 * Creates one customer per website from fixtures/customers.json. Each address book holds all
 * addresses of fixtures/addresses.json; the default billing and shipping address is default_address_id.
 * The fixture region (a state or province name) becomes the Magento region; it is left out for a country without
 * regions in this Magento version. A customer that exists is skipped.
 */
class CreateCustomers implements DataPatchInterface
{
    public function __construct(
        private readonly State $appState,
        private readonly WebsiteRepositoryInterface $websiteRepository,
        private readonly GroupRepositoryInterface $groupRepository,
        private readonly CustomerRepositoryInterface $customerRepository,
        private readonly CustomerInterfaceFactory $customerFactory,
        private readonly AddressInterfaceFactory $addressFactory,
        private readonly RegionInterfaceFactory $regionDataFactory,
        private readonly RegionResolver $regionResolver,
        private readonly GroupManagementInterface $groupManagement,
        private readonly EncryptorInterface $encryptor,
        private readonly Fixtures $fixtures
    ) {
    }

    public static function getDependencies(): array
    {
        return [CreateProducts::class];
    }

    public function getAliases(): array
    {
        return [];
    }

    public function apply(): self
    {
        $this->appState->emulateAreaCode(Area::AREA_ADMINHTML, fn () => $this->createCustomers());

        return $this;
    }

    private function createCustomers(): void
    {
        $addresses = $this->fixtures->addresses();

        foreach ($this->fixtures->customers() as $fixture) {
            $website   = $this->websiteRepository->get($fixture['website']);
            $websiteId = (int) $website->getId();
            if ($this->customerExists($fixture['email'], $websiteId)) {
                continue;
            }

            $storeId  = (int) $this->groupRepository->get($website->getDefaultGroupId())->getDefaultStoreId();
            $customer = $this->customerFactory->create();
            $customer->setWebsiteId($websiteId)
                ->setStoreId($storeId)
                ->setGroupId($this->groupManagement->getDefaultGroup($storeId)->getId())
                ->setFirstname($fixture['firstname'])
                ->setLastname($fixture['lastname'])
                ->setEmail($fixture['email'])
                ->setAddresses(array_map(
                    fn (array $address) => $this->address($address, $fixture),
                    $addresses
                ));

            $this->customerRepository->save($customer, $this->encryptor->getHash($fixture['password'], true));
        }
    }

    /**
     * @param array<string, mixed> $fixture  one entry of addresses.json
     * @param array<string, mixed> $customer one entry of customers.json
     */
    private function address(array $fixture, array $customer): AddressInterface
    {
        $isDefault = $fixture['id'] === $customer['default_address_id'];

        $address = $this->addressFactory->create();
        $address->setFirstname($customer['firstname'])
            ->setLastname($customer['lastname'])
            ->setCompany($fixture['label'])
            ->setStreet([...$fixture['street'], $fixture['house_number']])
            ->setPostcode($fixture['postcode'])
            ->setCity($fixture['city'])
            ->setCountryId($fixture['country'])
            ->setTelephone($fixture['telephone'])
            ->setIsDefaultBilling($isDefault)
            ->setIsDefaultShipping($isDefault);

        $region = $this->regionResolver->resolve($fixture);
        if ($region !== null) {
            $address->setRegionId((int) $region->getId());
            $address->setRegion(
                $this->regionDataFactory->create()
                    ->setRegionId((int) $region->getId())
                    ->setRegionCode($region->getCode())
                    ->setRegion($region->getName())
            );
        }

        return $address;
    }

    private function customerExists(string $email, int $websiteId): bool
    {
        try {
            $this->customerRepository->get($email, $websiteId);

            return true;
        } catch (NoSuchEntityException) {
            return false;
        }
    }
}
