<?php

declare(strict_types=1);

use MyParcelNL\DevSeed\Model\Fixtures;
use MyParcelNL\Magento\Service\Config;
use MyParcelNL\Magento\Service\DeliveryCosts;

afterEach(fn () => Mockery::close());

function seededDeliveryCosts(): DeliveryCosts
{
    $config = Mockery::mock(Config::class);
    $config->shouldReceive('getGeneralConfig')->with('matrix/delivery_costs')
        ->andReturn(json_encode((new Fixtures())->deliveryCosts()));
    $config->shouldReceive('getMagentoCarrierConfig')->with('shipping_cost')->andReturn('24.95');

    $deliveryCosts = newInstanceWithoutConstructor(DeliveryCosts::class);
    setPrivateProperty($deliveryCosts, 'config', $config);

    return $deliveryCosts;
}

it('prices the seeded matrix as the spec table says', function (
    string $country,
    string $carrier,
    int $packageType,
    string $deliveryType,
    float $amount,
    float $expected
) {
    $price = invokePrivateMethod(seededDeliveryCosts(), 'calculate', [[
        'carrier_name'  => $carrier,
        'package_type'  => $packageType,
        'country'       => $country,
        'weight'        => 1000,
        'order_amount'  => $amount,
        'delivery_type' => $deliveryType,
    ]]);

    expect($price)->toBe($expected);
})->with([
    'NL base'              => ['NL', 'postnl', 1, 'standard', 20.0, 6.95],
    'NL mailbox'           => ['NL', 'postnl', 2, 'standard', 20.0, 4.50],
    'NL UPS'               => ['NL', 'upsstandard', 1, 'standard', 20.0, 8.95],
    'NL from 50'           => ['NL', 'postnl', 1, 'standard', 50.0, 1.00],
    'NL mailbox from 50'   => ['NL', 'postnl', 2, 'standard', 60.0, 1.00],
    'NL UPS from 50'       => ['NL', 'upsstandard', 1, 'standard', 60.0, 1.00],
    'NL pickup from 50'    => ['NL', 'postnl', 1, 'pickup', 50.0, 0.00],
    'NL pickup below 50'   => ['NL', 'postnl', 1, 'pickup', 49.99, 6.95],
    'BE base'              => ['BE', 'postnl', 1, 'standard', 20.0, 9.95],
    'BE mailbox'           => ['BE', 'postnl', 2, 'standard', 20.0, 7.50],
    'BE from 70'           => ['BE', 'postnl', 1, 'standard', 70.0, 2.95],
    'DE'                   => ['DE', 'postnl', 1, 'standard', 20.0, 14.95],
    'US'                   => ['US', 'postnl', 1, 'standard', 20.0, 24.95],
]);
