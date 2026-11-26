<?php

declare(strict_types=1);

namespace MyParcelNL\DevSeed\Console\Command;

use Magento\Framework\App\Area;
use Magento\Framework\App\AreaList;
use Magento\Framework\App\ResourceConnection;
use Magento\Framework\App\State;
use MyParcelNL\DevSeed\Model\OrderCreator;
use MyParcelNL\DevSeed\Model\OrderPlanner;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Input\InputOption;
use Symfony\Component\Console\Output\OutputInterface;

/**
 * bin/magento myparcel:seed:orders: places the planned seed orders once.
 * Does nothing when sales_order has rows, so the entrypoint can run it on every first start.
 */
class SeedOrders extends Command
{
    public function __construct(
        private readonly State $appState,
        private readonly AreaList $areaList,
        private readonly ResourceConnection $resource,
        private readonly OrderPlanner $planner,
        private readonly OrderCreator $orderCreator
    ) {
        parent::__construct();
    }

    protected function configure(): void
    {
        $this->setName('myparcel:seed:orders')
            ->setDescription('Create seed orders, most of them MyParcel orders with delivery options')
            ->addOption('count', null, InputOption::VALUE_REQUIRED, 'Number of orders', '200')
            ->addOption('seed', null, InputOption::VALUE_REQUIRED, 'Random seed of the order plan', '2026');
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        $connection = $this->resource->getConnection();
        $existing   = (int) $connection->fetchOne('SELECT COUNT(*) FROM ' . $this->resource->getTableName('sales_order'));
        if ($existing > 0) {
            $output->writeln(sprintf('sales_order has %d orders: no seed orders created', $existing));

            return Command::SUCCESS;
        }

        $plan  = $this->planner->plan((int) $input->getOption('count'), (int) $input->getOption('seed'));
        $start = microtime(true);

        // a real area, as in a checkout: emulateAreaCode() leaves out the events and DI of the area
        $this->appState->setAreaCode(Area::AREA_FRONTEND);
        $this->areaList->getArea(Area::AREA_FRONTEND)->load(Area::PART_CONFIG);

        foreach ($plan as $index => $spec) {
            try {
                $this->orderCreator->create($spec);
            } catch (\Throwable $e) {
                throw new \RuntimeException(sprintf('Seed order %d failed: %s', $index + 1, $e->getMessage()), 0, $e);
            }

            if (($index + 1) % 25 === 0) {
                $output->writeln(sprintf('%d of %d orders created', $index + 1, count($plan)));
            }
        }

        $output->writeln(sprintf('Created %d seed orders in %d s', count($plan), (int) round(microtime(true) - $start)));
        if ($this->orderCreator->fallbackRates() > 0) {
            $output->writeln(sprintf(
                '%d MyParcel orders use the configured shipping cost: the carrier returned no rate',
                $this->orderCreator->fallbackRates()
            ));
        }

        return Command::SUCCESS;
    }
}
