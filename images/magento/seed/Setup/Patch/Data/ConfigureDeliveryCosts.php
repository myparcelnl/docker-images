<?php

declare(strict_types=1);

namespace MyParcelNL\DevSeed\Setup\Patch\Data;

use Magento\Framework\App\Config\Storage\WriterInterface;
use Magento\Framework\Setup\Patch\DataPatchInterface;
use MyParcelNL\DevSeed\Model\Fixtures;

/**
 * Writes the starter delivery costs matrix of the plugin from fixtures/delivery-costs.json, on default scope.
 * matrix/use_free_shipping keeps its default (1).
 */
class ConfigureDeliveryCosts implements DataPatchInterface
{
    public const XML_PATH_DELIVERY_COSTS = 'myparcelnl_magento_general/matrix/delivery_costs';

    public function __construct(
        private readonly WriterInterface $configWriter,
        private readonly Fixtures $fixtures
    ) {
    }

    public static function getDependencies(): array
    {
        return [ConfigureStores::class];
    }

    public function getAliases(): array
    {
        return [];
    }

    public function apply(): self
    {
        $this->configWriter->save(
            self::XML_PATH_DELIVERY_COSTS,
            json_encode($this->fixtures->deliveryCosts(), JSON_THROW_ON_ERROR)
        );

        return $this;
    }
}
