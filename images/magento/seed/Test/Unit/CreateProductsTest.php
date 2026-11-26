<?php

declare(strict_types=1);

use MyParcelNL\DevSeed\Setup\Patch\Data\CreateProducts;

it('skips an attribute the plugin does not have', function () {
    $attributes = ['myparcel_classification' => '4901990000', 'myparcel_age_check' => '1', 'myparcel_new' => 1];

    $filtered = CreateProducts::filterExistingAttributes(
        $attributes,
        fn (string $code): bool => 'myparcel_new' !== $code
    );

    expect($filtered)->toBe(['myparcel_classification' => '4901990000', 'myparcel_age_check' => '1']);
});

it('asks about each attribute', function () {
    $asked = [];

    CreateProducts::filterExistingAttributes(['a' => 1, 'b' => 2], function (string $code) use (&$asked): bool {
        $asked[] = $code;

        return true;
    });

    expect($asked)->toBe(['a', 'b']);
});
