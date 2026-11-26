<?php

declare(strict_types=1);

use MyParcelNL\DevSeed\Model\Fixtures;

/** The myparcel_* product attribute codes the installed plugin adds in its UpgradeData. */
function pluginProductAttributeCodes(): array
{
    $source = file_get_contents(__DIR__ . '/../../vendor/myparcelnl/magento/src/Setup/UpgradeData.php');

    preg_match_all('/(?<!removeAttribute\()Product::ENTITY,\s*\'(myparcel_\w+)\'/', $source, $matches);

    $codes = array_values(array_unique($matches[1]));
    sort($codes);

    return $codes;
}

it('gives every product a 10-digit HS code', function () {
    foreach ((new Fixtures())->products() as $product) {
        expect($product['hs_code'])->toMatch('/^\d{10}$/', $product['sku']);
        expect($product['attributes']['myparcel_classification'])->toBe($product['hs_code']);
    }
});

it('names every product after its MyParcel settings', function () {
    $products = (new Fixtures())->products();
    $names    = array_column($products, 'name');

    foreach ([
        'Package 1kg age check off',
        'Package 1kg age check on',
        'Mailbox 10 fit 100gr',
        'Mailbox fit off 100gr',
        'Digital stamp 20gr',
        'Package 4.5kg large format',
        'Package 2kg excluded from parcel lockers',
    ] as $name) {
        expect($names)->toContain($name);
    }

    expect(count($products))->toBeBetween(35, 45)
        ->and(count(array_unique(array_column($products, 'sku'))))->toBe(count($products));
});

it('covers every product attribute of the plugin', function () {
    $used = [];
    foreach ((new Fixtures())->products() as $product) {
        $used = array_merge($used, array_keys($product['attributes']));
    }
    $used = array_values(array_unique($used));
    sort($used);

    expect(pluginProductAttributeCodes())->not->toBeEmpty()
        ->and($used)->toBe(pluginProductAttributeCodes());
});

it('keeps the matrix below 10 rules', function () {
    expect(count((new Fixtures())->deliveryCosts()))->toBe(9);
});
