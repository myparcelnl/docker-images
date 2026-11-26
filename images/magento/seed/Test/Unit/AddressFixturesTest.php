<?php

declare(strict_types=1);

use libphonenumber\PhoneNumberUtil;
use MyParcelNL\DevSeed\Model\Fixtures;

const FIXTURE_COUNTRIES = ['NL', 'BE', 'DE', 'FR', 'IT', 'US'];

it('has three addresses per country', function () {
    $addresses = (new Fixtures())->addresses();

    expect($addresses)->toHaveCount(18);

    foreach (FIXTURE_COUNTRIES as $country) {
        $inCountry = array_filter($addresses, fn (array $address) => $address['country'] === $country);
        expect($inCountry)->toHaveCount(3);
    }

    expect(array_unique(array_column($addresses, 'id')))->toHaveCount(18);
});

it('gives every address a valid phone number for its country', function () {
    $util = PhoneNumberUtil::getInstance();

    $invalid = [];

    foreach ((new Fixtures())->addresses() as $address) {
        $number = $util->parse($address['telephone'], $address['country']);

        if (! $util->isValidNumberForRegion($number, $address['country'])) {
            $invalid[] = $address['id'];
        }
    }

    expect($invalid)->toBe([]);
});

// Magento 2.4.8 requires a region for BE, IT and US addresses (general/region/state_required)
it('gives every BE, IT and US address a region', function () {
    foreach ((new Fixtures())->addresses() as $address) {
        if (in_array($address['country'], ['BE', 'IT', 'US'], true)) {
            expect($address['region'] ?? '')->not->toBe('');
        }
    }
});

it('has one customer per website', function () {
    $fixtures = new Fixtures();
    $countryById = array_column($fixtures->addresses(), 'country', 'id');
    $customers = $fixtures->customers();

    expect(array_column($customers, 'website'))->toBe(['nl', 'be', 'it']);

    foreach ($customers as $customer) {
        expect($customer['email'])->toEndWith('@example.com');
        expect(strlen($customer['password']))->toBeGreaterThanOrEqual(8);

        $classes = (int) preg_match('/[a-z]/', $customer['password'])
            + (int) preg_match('/[A-Z]/', $customer['password'])
            + (int) preg_match('/\d/', $customer['password'])
            + (int) preg_match('/[^a-zA-Z\d]/', $customer['password']);
        expect($classes)->toBeGreaterThanOrEqual(3);

        expect($countryById[$customer['default_address_id']])->toBe(strtoupper($customer['website']));
    }
});

it('uses no made-up Dutch postcode', function () {
    $postcodes = array_column(
        array_filter((new Fixtures())->addresses(), fn (array $address) => 'NL' === $address['country']),
        'postcode'
    );

    expect($postcodes)->not->toContain('1111 XX', '1010 OO', '1234 AB');
});
