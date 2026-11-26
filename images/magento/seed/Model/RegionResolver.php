<?php

declare(strict_types=1);

namespace MyParcelNL\DevSeed\Model;

use Magento\Directory\Model\Region;
use Magento\Directory\Model\RegionFactory;
use Magento\Directory\Model\ResourceModel\Region\CollectionFactory as RegionCollectionFactory;

/**
 * Finds the Magento region of a fixture address from its region name (a state or province).
 * Returns null when the address has no region or the country has no regions in this Magento version.
 */
class RegionResolver
{
    public function __construct(
        private readonly RegionFactory $regionFactory,
        private readonly RegionCollectionFactory $regionCollectionFactory
    ) {
    }

    /** @param array<string, mixed> $fixture one entry of addresses.json */
    public function resolve(array $fixture): ?Region
    {
        if (empty($fixture['region']) || ! $this->countryHasRegions($fixture['country'])) {
            return null;
        }

        $region = $this->regionFactory->create()->loadByName($fixture['region'], $fixture['country']);
        if (! $region->getId()) {
            throw new \RuntimeException(sprintf('Unknown region "%s" for address %s', $fixture['region'], $fixture['id']));
        }

        return $region;
    }

    private function countryHasRegions(string $countryId): bool
    {
        return $this->regionCollectionFactory->create()->addCountryFilter($countryId)->getSize() > 0;
    }
}
