<?php

declare(strict_types=1);

namespace MyParcelNL\DevSeed\Setup\Patch\Data;

use Magento\Framework\App\Config\Storage\WriterInterface;
use Magento\Framework\Setup\Patch\DataPatchInterface;
use Magento\Store\Model\Group;
use Magento\Store\Model\GroupFactory;
use Magento\Store\Model\ResourceModel\Group as GroupResource;
use Magento\Store\Model\ResourceModel\Store as StoreResource;
use Magento\Store\Model\ResourceModel\Website as WebsiteResource;
use Magento\Store\Model\Store;
use Magento\Store\Model\StoreFactory;
use Magento\Store\Model\StoreManagerInterface;
use Magento\Store\Model\Website;
use Magento\Store\Model\WebsiteFactory;

/**
 * Creates the websites nl, be and it with their store groups and store views.
 * The default website, group and store view of the install become nl. All groups share the default
 * root category. Base URLs stay on default scope: web/url/use_store puts the store code in the path.
 */
class CreateWebsites implements DataPatchInterface
{
    /** Website code => name, store view code => name. The first store view is the default of the website. */
    public const WEBSITES = [
        'nl' => ['name' => 'Nederland', 'stores' => ['nl' => 'Nederlands']],
        'be' => ['name' => 'België', 'stores' => ['be_nl' => 'Nederlands', 'be_fr' => 'Français']],
        'it' => ['name' => 'Italia', 'stores' => ['it' => 'Italiano']],
    ];

    public function __construct(
        private readonly WebsiteFactory $websiteFactory,
        private readonly WebsiteResource $websiteResource,
        private readonly GroupFactory $groupFactory,
        private readonly GroupResource $groupResource,
        private readonly StoreFactory $storeFactory,
        private readonly StoreResource $storeResource,
        private readonly StoreManagerInterface $storeManager,
        private readonly WriterInterface $configWriter
    ) {
    }

    public static function getDependencies(): array
    {
        return [];
    }

    public function getAliases(): array
    {
        return [];
    }

    public function apply(): self
    {
        $this->renameInstallScope();

        $rootCategoryId = (int) $this->loadGroup('nl')->getRootCategoryId();
        if (! $rootCategoryId) {
            throw new \RuntimeException('The default store group of the install has no root category');
        }
        $sortOrder = 0;

        foreach (self::WEBSITES as $websiteCode => $definition) {
            $website = $this->loadWebsite($websiteCode);
            $website->setCode($websiteCode)->setName($definition['name'])->setSortOrder($sortOrder++);
            $this->websiteResource->save($website);

            $group = $this->loadGroup($websiteCode);
            $group->setCode($websiteCode)
                ->setName($definition['name'])
                ->setWebsiteId($website->getId())
                ->setRootCategoryId($rootCategoryId);
            $this->groupResource->save($group);

            $storeIds = [];
            $storeSortOrder = 0;
            foreach ($definition['stores'] as $storeCode => $storeName) {
                $store = $this->loadStore($storeCode);
                $store->setCode($storeCode)
                    ->setName($storeName)
                    ->setWebsiteId($website->getId())
                    ->setGroupId($group->getId())
                    ->setSortOrder($storeSortOrder++)
                    ->setIsActive(1);
                $this->storeResource->save($store);
                $storeIds[] = (int) $store->getId();
            }

            $group->setDefaultStoreId($storeIds[0]);
            $this->groupResource->save($group);
            $website->setDefaultGroupId($group->getId());
            $this->websiteResource->save($website);
        }

        $this->configWriter->save(Store::XML_PATH_STORE_IN_URL, '1');
        $this->storeManager->reinitStores();

        return $this;
    }

    /** setup:install creates base / main_website_store / default; they become the nl scope. */
    private function renameInstallScope(): void
    {
        $website = $this->websiteFactory->create();
        $this->websiteResource->load($website, 'base', 'code');
        if ($website->getId()) {
            $website->setCode('nl');
            $this->websiteResource->save($website);
        }

        $group = $this->groupFactory->create();
        $this->groupResource->load($group, 'main_website_store', 'code');
        if ($group->getId()) {
            $group->setCode('nl');
            $this->groupResource->save($group);
        }

        $store = $this->storeFactory->create();
        $this->storeResource->load($store, 'default', 'code');
        if ($store->getId()) {
            $store->setCode('nl');
            $this->storeResource->save($store);
        }
    }

    private function loadWebsite(string $code): Website
    {
        $website = $this->websiteFactory->create();
        $this->websiteResource->load($website, $code, 'code');

        return $website;
    }

    private function loadGroup(string $code): Group
    {
        $group = $this->groupFactory->create();
        $this->groupResource->load($group, $code, 'code');

        return $group;
    }

    private function loadStore(string $code): Store
    {
        $store = $this->storeFactory->create();
        $this->storeResource->load($store, $code, 'code');

        return $store;
    }
}
