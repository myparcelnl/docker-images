<?php

declare(strict_types=1);

use MyParcelNL\DevSeed\Model\DeliveryOptionsFactory;

it('builds the shape the plugin reads', function () {
    $options = (new DeliveryOptionsFactory())->create(
        'postnl',
        'NL',
        'package',
        'evening',
        ['signature' => true, 'onlyRecipient' => false],
        '2026-11-25'
    );

    expect($options)->toBe([
        'carrier'         => 'postnl',
        'date'            => '2026-11-25 00:00:00.000000',
        'deliveryType'    => 'evening',
        'isPickup'        => false,
        'packageType'     => 'package',
        'shipmentOptions' => ['signature' => true, 'onlyRecipient' => false],
    ]);
});

it('keeps an empty shipment options list a JSON object', function () {
    $options = (new DeliveryOptionsFactory())->create('postnl', 'DE', 'package', 'standard', [], null);

    expect(json_encode($options))->toContain('"shipmentOptions":{}');
});

it('leaves out the date key when there is no delivery date', function () {
    $options = (new DeliveryOptionsFactory())->create('postnl', 'DE', 'package', 'standard', [], null);

    expect($options)->not->toHaveKey('date')
        ->and(array_keys($options))->toBe(['carrier', 'deliveryType', 'isPickup', 'packageType', 'shipmentOptions']);
});

it('refuses options the carrier does not allow', function (string $country, string $package, string $type, array $shipmentOptions) {
    (new DeliveryOptionsFactory())->create('postnl', $country, $package, $type, $shipmentOptions, '2026-11-25');
})->throws(InvalidArgumentException::class)->with([
    'pickup'               => ['NL', 'package', 'pickup', []],
    'morning outside NL'   => ['BE', 'package', 'morning', []],
    'evening outside NL'   => ['DE', 'package', 'evening', []],
    'mailbox outside NL'   => ['BE', 'mailbox', 'standard', []],
    'digital stamp abroad' => ['FR', 'digital_stamp', 'standard', []],
    'unknown option'       => ['NL', 'package', 'standard', ['age_check' => true]],
]);
