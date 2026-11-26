<?php

declare(strict_types=1);

use MyParcelNL\DevSeed\Model\DeliveryOptionsFactory;
use MyParcelNL\DevSeed\Model\Fixtures;
use MyParcelNL\DevSeed\Model\OrderPlanner;

function planner(): OrderPlanner
{
    return new OrderPlanner(new Fixtures(), new DeliveryOptionsFactory(), strtotime('2026-11-24 12:00:00 UTC'));
}

/** @return array<string, string> address id => country */
function addressCountries(): array
{
    return array_column((new Fixtures())->addresses(), 'country', 'id');
}

it('plans the requested number of orders', function () {
    expect(planner()->plan(200))->toHaveCount(200);
});

it('ships about 80 percent with MyParcel', function () {
    $myparcel = array_filter(planner()->plan(200), fn (array $spec) => $spec['shipping'] === 'myparcel');

    expect(count($myparcel))->toBeGreaterThanOrEqual(150)->toBeLessThanOrEqual(170);
});

it('gives delivery options only to MyParcel orders', function () {
    foreach (planner()->plan(200) as $spec) {
        expect($spec['delivery_options'] !== null)->toBe($spec['shipping'] === 'myparcel');
    }
});

it('gives a delivery date only to NL and BE orders', function () {
    $countries = addressCountries();

    foreach (planner()->plan(200) as $spec) {
        if ($spec['delivery_options'] === null) {
            continue;
        }
        $hasDate = in_array($countries[$spec['address_id']], ['NL', 'BE'], true);
        expect(array_key_exists('date', $spec['delivery_options']))->toBe($hasDate);
    }
});

it('plans no pickup orders', function () {
    foreach (planner()->plan(200) as $spec) {
        expect($spec['delivery_options']['isPickup'] ?? false)->toBeFalse()
            ->and($spec['delivery_options']['deliveryType'] ?? null)->not->toBe('pickup');
    }
});

it('spreads orders over websites, countries and payments', function () {
    $plan      = planner()->plan(200);
    $countries = addressCountries();

    $count = fn (array $values) => array_count_values(array_map('strval', $values));

    $stores = $count(array_column($plan, 'store_code'));
    foreach (['nl', 'be_nl', 'be_fr', 'it'] as $store) {
        expect($stores[$store] ?? 0)->toBeGreaterThanOrEqual(5);
    }

    $perCountry = $count(array_map(fn (array $spec) => $countries[$spec['address_id']], $plan));
    foreach (array_unique($countries) as $country) {
        expect($perCountry[$country] ?? 0)->toBeGreaterThanOrEqual(5);
    }

    $payments = $count(array_column($plan, 'payment'));
    foreach (['checkmo', 'banktransfer', 'cashondelivery'] as $payment) {
        expect($payments[$payment] ?? 0)->toBeGreaterThanOrEqual(5);
    }

    $guests = array_filter($plan, fn (array $spec) => $spec['customer_email'] === null);
    expect(count($guests))->toBeGreaterThan(0)->toBeLessThan(200);
});

it('gives customer orders the customer of the store website', function () {
    $emails = ['nl' => 'customer-nl@example.com', 'be_nl' => 'customer-be@example.com',
        'be_fr' => 'customer-be@example.com', 'it' => 'customer-it@example.com'];

    foreach (planner()->plan(200) as $spec) {
        if ($spec['customer_email'] === null) {
            expect($spec['guest']['email'])->toEndWith('@example.com');
            continue;
        }
        expect($spec['customer_email'])->toBe($emails[$spec['store_code']]);
    }
});

it('keeps most orders pending', function () {
    $plan    = planner()->plan(200);
    $pending = array_filter($plan, fn (array $spec) => $spec['status'] === 'pending');

    expect(count($pending) / 200)->toBeGreaterThanOrEqual(0.7);

    foreach ($plan as $spec) {
        expect($spec['status'])->toBeIn(['pending', 'processing', 'complete']);
        if ($spec['status'] === 'complete') {
            expect($spec['shipping'])->not->toBe('myparcel');
        }
    }
});

it('dates orders within the last 30 days', function () {
    $now = strtotime('2026-11-24 12:00:00 UTC');

    foreach (planner()->plan(200) as $spec) {
        $time = strtotime($spec['created_at'] . ' UTC');
        expect($time)->toBeLessThanOrEqual($now)->toBeGreaterThanOrEqual($now - 30 * 86400);
    }
});

it('is deterministic for a seed', function () {
    expect(planner()->plan(200, 1))->toEqual(planner()->plan(200, 1))
        ->and(planner()->plan(200, 1))->not->toEqual(planner()->plan(200, 2));
});

it('only uses options the carrier allows', function () {
    $countries = addressCountries();

    foreach (planner()->plan(200) as $spec) {
        $options = $spec['delivery_options'];
        if ($options === null || $countries[$spec['address_id']] === 'NL') {
            continue;
        }

        expect($options['deliveryType'])->not->toBeIn(['morning', 'evening'])
            ->and($options['packageType'])->not->toBeIn(['mailbox', 'digital_stamp']);
    }
});

it('only plans products that exist', function () {
    $skus = array_column((new Fixtures())->products(), 'sku');

    foreach (planner()->plan(200) as $spec) {
        expect($spec['items'])->not->toBeEmpty();
        foreach ($spec['items'] as [$sku, $qty]) {
            expect($sku)->toBeIn($skus)->and($qty)->toBeGreaterThan(0);
        }
    }
});

it('reaches the free shipping amount for free shipping orders', function () {
    $prices = array_column((new Fixtures())->products(), 'price', 'sku');

    foreach (planner()->plan(200) as $spec) {
        if ($spec['shipping'] !== 'freeshipping') {
            continue;
        }
        $total = array_sum(array_map(fn (array $item) => $prices[$item[0]] * $item[1], $spec['items']));
        expect($total)->toBeGreaterThanOrEqual(100);
    }
});

// Plugin Checkout::getDeliveryOptionsConfig() offers no morning or evening delivery for an age check product
it('never combines age check with morning or evening', function () {
    $ageCheck = array_column(array_filter(
        (new Fixtures())->products(),
        fn (array $product) => ($product['attributes']['myparcel_age_check'] ?? '0') === '1'
    ), 'sku');

    foreach ([2026, 1, 2, 3] as $seed) {
        foreach (planner()->plan(200, $seed) as $spec) {
            if (! in_array($spec['delivery_options']['deliveryType'] ?? null, ['morning', 'evening'], true)) {
                continue;
            }
            expect(array_intersect(array_column($spec['items'], 0), $ageCheck))->toBe([]);
        }
    }
});
