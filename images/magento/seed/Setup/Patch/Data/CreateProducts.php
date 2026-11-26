<?php

declare(strict_types=1);

namespace MyParcelNL\DevSeed\Setup\Patch\Data;

use Magento\Catalog\Api\CategoryLinkManagementInterface;
use Magento\Catalog\Api\CategoryRepositoryInterface;
use Magento\Catalog\Api\Data\CategoryInterfaceFactory;
use Magento\Catalog\Api\Data\ProductInterfaceFactory;
use Magento\Catalog\Api\ProductRepositoryInterface;
use Magento\Catalog\Model\Product;
use Magento\Catalog\Model\Product\Attribute\Source\Status;
use Magento\Catalog\Model\Product\Type;
use Magento\Catalog\Model\Product\Visibility;
use Magento\Catalog\Model\ResourceModel\Category\CollectionFactory as CategoryCollectionFactory;
use Magento\Eav\Model\Config as EavConfig;
use Magento\Framework\App\Area;
use Magento\Framework\App\Config\ScopeConfigInterface;
use Magento\Framework\App\State;
use Magento\Framework\Exception\NoSuchEntityException;
use Magento\Framework\Setup\Patch\DataPatchInterface;
use Magento\Store\Api\GroupRepositoryInterface;
use Magento\Store\Api\WebsiteRepositoryInterface;
use Magento\Store\Model\Store;
use Magento\Store\Model\StoreManagerInterface;
use MyParcelNL\DevSeed\Model\Fixtures;
use Psr\Log\LoggerInterface;

/**
 * Creates the simple products of fixtures/products.json in one category, in all seed websites, with stock 1000.
 * A myparcel_* attribute that the installed plugin does not have is skipped with a log line, so an older
 * plugin does not fail the seed. A SKU that exists already is left as it is.
 */
class CreateProducts implements DataPatchInterface
{
    public const CATEGORY_NAME = 'MyParcel test products';
    public const STOCK         = 1000;

    /** @var array<string, bool> attribute code => exists */
    private array $knownAttributes = [];

    public function __construct(
        private readonly State $appState,
        private readonly StoreManagerInterface $storeManager,
        private readonly WebsiteRepositoryInterface $websiteRepository,
        private readonly GroupRepositoryInterface $groupRepository,
        private readonly ProductInterfaceFactory $productFactory,
        private readonly ProductRepositoryInterface $productRepository,
        private readonly CategoryInterfaceFactory $categoryFactory,
        private readonly CategoryRepositoryInterface $categoryRepository,
        private readonly CategoryCollectionFactory $categoryCollectionFactory,
        private readonly CategoryLinkManagementInterface $categoryLinkManagement,
        private readonly EavConfig $eavConfig,
        private readonly ScopeConfigInterface $scopeConfig,
        private readonly Fixtures $fixtures,
        private readonly LoggerInterface $logger
    ) {
    }

    public static function getDependencies(): array
    {
        return [ConfigureDeliveryCosts::class];
    }

    public function getAliases(): array
    {
        return [];
    }

    /**
     * @param array<string, mixed>   $attributes code => value
     * @param callable(string): bool $exists
     * @return array<string, mixed>
     */
    public static function filterExistingAttributes(array $attributes, callable $exists): array
    {
        return array_filter($attributes, static fn (string $code): bool => $exists($code), ARRAY_FILTER_USE_KEY);
    }

    public function apply(): self
    {
        $this->appState->emulateAreaCode(Area::AREA_ADMINHTML, fn () => $this->createProducts());

        return $this;
    }

    private function createProducts(): void
    {
        // Attribute values go to the admin scope (store 0), not to the default store view
        $this->storeManager->setCurrentStore(Store::ADMIN_CODE);

        $websiteIds = [];
        foreach (array_keys(CreateWebsites::WEBSITES) as $code) {
            $websiteIds[] = (int) $this->websiteRepository->get($code)->getId();
        }

        $categoryId     = $this->categoryId();
        $attributeSetId = (int) $this->eavConfig->getEntityType(Product::ENTITY)->getDefaultAttributeSetId();
        $taxClassId     = (int) $this->scopeConfig->getValue('tax/classes/default_product_tax_class');
        $exists         = $this->attributeExists(...);

        foreach ($this->fixtures->products() as $fixture) {
            if ($this->skuExists($fixture['sku'])) {
                continue;
            }

            $product = $this->productFactory->create();
            $product->setSku($fixture['sku'])
                ->setName($fixture['name'])
                ->setTypeId(Type::TYPE_SIMPLE)
                ->setAttributeSetId($attributeSetId)
                ->setPrice($fixture['price'])
                ->setWeight($fixture['weight_grams'] / 1000)
                ->setVisibility(Visibility::VISIBILITY_BOTH)
                ->setStatus(Status::STATUS_ENABLED);
            $product->setWebsiteIds($websiteIds)
                ->setTaxClassId($taxClassId)
                ->setUrlKey($this->urlKey($fixture['name'], $fixture['sku']))
                ->setStockData(['qty' => self::STOCK, 'is_in_stock' => 1, 'use_config_manage_stock' => 1])
                ->setQuantityAndStockStatus(['qty' => self::STOCK, 'is_in_stock' => 1]);

            foreach (self::filterExistingAttributes($fixture['attributes'], $exists) as $code => $value) {
                $product->setData($code, $value);
            }

            $this->productRepository->save($product);
            $this->categoryLinkManagement->assignProductToCategories($fixture['sku'], [$categoryId]);
        }
    }

    /** Logs each missing attribute once. */
    private function attributeExists(string $code): bool
    {
        if (! array_key_exists($code, $this->knownAttributes)) {
            $attribute                    = $this->eavConfig->getAttribute(Product::ENTITY, $code);
            $this->knownAttributes[$code] = $attribute && $attribute->getId();
            if (! $this->knownAttributes[$code]) {
                $this->logger->warning(sprintf('DevSeed: product attribute %s does not exist, products are created without it', $code));
            }
        }

        return $this->knownAttributes[$code];
    }

    private function skuExists(string $sku): bool
    {
        try {
            $this->productRepository->get($sku);

            return true;
        } catch (NoSuchEntityException) {
            return false;
        }
    }

    /** One category below the root category of the seed websites, shown in the menu. */
    private function categoryId(): int
    {
        $website  = $this->websiteRepository->get('nl');
        $parentId = (int) $this->groupRepository->get($website->getDefaultGroupId())->getRootCategoryId();

        $existing = $this->categoryCollectionFactory->create()
            ->addAttributeToFilter('name', self::CATEGORY_NAME)
            ->addAttributeToFilter('parent_id', $parentId)
            ->getFirstItem();
        if ($existing->getId()) {
            return (int) $existing->getId();
        }

        $category = $this->categoryFactory->create();
        $category->setName(self::CATEGORY_NAME)
            ->setParentId($parentId)
            ->setIsActive(true)
            ->setIncludeInMenu(true);
        $category->setData('is_anchor', 1);

        return (int) $this->categoryRepository->save($category)->getId();
    }

    private function urlKey(string $name, string $sku): string
    {
        return trim((string) preg_replace('/[^a-z0-9]+/', '-', strtolower($name . ' ' . $sku)), '-');
    }
}
