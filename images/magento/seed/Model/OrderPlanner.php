<?php

declare(strict_types=1);

namespace MyParcelNL\DevSeed\Model;

/**
 * Plans the seed orders as plain arrays: store, customer or guest, address, items, shipping, delivery options,
 * payment, status and date. No Magento dependency, so unit tests run on the host.
 * The same seed gives the same plan (mt_srand); about 80 % MyParcel orders, never pickup.
 */
class OrderPlanner
{
    private const STORES     = ['nl' => 40, 'be_nl' => 20, 'be_fr' => 15, 'it' => 25];
    private const COUNTRIES  = ['NL' => 35, 'BE' => 20, 'DE' => 10, 'FR' => 10, 'IT' => 15, 'US' => 10];
    private const PAYMENTS   = ['checkmo', 'banktransfer', 'cashondelivery'];
    private const WEBSITES   = ['nl' => 'nl', 'be_nl' => 'be', 'be_fr' => 'be', 'it' => 'it'];
    private const FIRSTNAMES = ['Sanne', 'Bram', 'Noor', 'Luca', 'Emma', 'Milan', 'Julia', 'Lars', 'Sofia', 'Tom'];
    private const LASTNAMES  = ['Jansen', 'Bakker', 'Smit', 'Maes', 'Wouters', 'Bianchi', 'Romano', 'Dekker', 'Claes', 'Ricci'];
    private const DAY        = 86400;

    private int $now;

    public function __construct(
        private readonly Fixtures $fixtures,
        private readonly DeliveryOptionsFactory $deliveryOptionsFactory,
        ?int $now = null
    ) {
        $this->now = $now ?? time();
    }

    /**
     * @return array<int, array{store_code: string, customer_email: string|null, guest: array|null, address_id: string,
     *     items: array<int, array{0: string, 1: int}>, shipping: string, delivery_options: array|null, payment: string,
     *     status: string, created_at: string}> sorted by created_at (UTC)
     */
    public function plan(int $count, int $seed = 2026): array
    {
        mt_srand($seed);

        $shipping = $this->shuffle(array_merge(
            array_fill(0, $myparcel = (int) round($count * 0.8), 'myparcel'),
            array_fill(0, $flatrate = intdiv($count - $myparcel, 2), 'flatrate'),
            array_fill(0, $count - $myparcel - $flatrate, 'freeshipping')
        ));
        $statuses = $this->statuses($shipping);

        $customers = array_column($this->fixtures->customers(), 'email', 'website');
        $addresses = [];
        foreach ($this->fixtures->addresses() as $address) {
            $addresses[$address['country']][] = $address['id'];
        }

        $plan = [];
        for ($i = 0; $i < $count; $i++) {
            $store     = $this->weighted(self::STORES);
            $country   = $this->weighted(self::COUNTRIES);
            $createdAt = $this->now - mt_rand(0, 30 * self::DAY - 1);
            $email     = mt_rand(0, 1) ? ($customers[self::WEBSITES[$store]] ?? null) : null;

            $spec = [
                'store_code'       => $store,
                'customer_email'   => $email,
                'guest'            => $email === null ? $this->guest($i) : null,
                'address_id'       => $this->pick($addresses[$country]),
                'items'            => [],
                'shipping'         => $shipping[$i],
                'delivery_options' => null,
                'payment'          => $this->pick(self::PAYMENTS),
                'status'           => $statuses[$i],
                'created_at'       => gmdate('Y-m-d H:i:s', $createdAt),
            ];

            if ($shipping[$i] === 'myparcel') {
                [$spec['items'], $spec['delivery_options']] = $this->myParcelOrder($country, $createdAt);
            } else {
                $spec['items'] = $this->packageItems($country, false, $shipping[$i] === 'freeshipping' ? 100.0 : 0.0);
            }

            $plan[] = $spec;
        }

        usort($plan, fn (array $a, array $b) => $a['created_at'] <=> $b['created_at']);

        return $plan;
    }

    /**
     * About 10 % complete (never MyParcel: a shipment needs a MyParcel label), 15 % processing, the rest pending.
     *
     * @param array<int, string> $shipping
     * @return array<int, string>
     */
    private function statuses(array $shipping): array
    {
        $count    = count($shipping);
        $statuses = array_fill(0, $count, 'pending');
        $other    = $this->shuffle(array_keys(array_filter($shipping, fn (string $method) => $method !== 'myparcel')));

        foreach (array_slice($other, 0, (int) round($count * 0.1)) as $index) {
            $statuses[$index] = 'complete';
        }

        $pending = $this->shuffle(array_keys(array_filter($statuses, fn (string $status) => $status === 'pending')));
        foreach (array_slice($pending, 0, (int) round($count * 0.15)) as $index) {
            $statuses[$index] = 'processing';
        }

        return $statuses;
    }

    /** @return array{0: array<int, array{0: string, 1: int}>, 1: array} */
    private function myParcelOrder(string $country, int $createdAt): array
    {
        $date = in_array($country, ['NL', 'BE'], true) ? $this->deliveryDate($createdAt) : null;

        if ($country === 'NL') {
            $carrier = mt_rand(1, 4) === 1 ? 'dhlforyou' : 'postnl';
            $package = $carrier === 'postnl' ? $this->weighted(['package' => 70, 'mailbox' => 20, 'digital_stamp' => 10]) : 'package';

            if ($package === 'mailbox') {
                $product = $this->pick($this->products(fn (array $p) => $this->isMailbox($p)));

                return [[[$product['sku'], 1]], $this->deliveryOptionsFactory->create($carrier, $country, $package, 'standard', [
                    'priorityDelivery' => ! empty($product['attributes']['myparcel_priority_delivery']),
                ], $date)];
            }

            if ($package === 'digital_stamp') {
                $product = $this->pick($this->products(fn (array $p) => ! empty($p['attributes']['myparcel_digital_stamp'])));

                return [[[$product['sku'], 1]], $this->deliveryOptionsFactory->create($carrier, $country, $package, 'standard', [], $date)];
            }

            $type = $carrier === 'postnl' ? $this->weighted(['standard' => 70, 'morning' => 15, 'evening' => 15]) : 'standard';

            // the checkout offers no morning or evening delivery for an age check product
            $ageCheck = $type === 'standard';

            return [$this->packageItems($country, true, 0.0, $ageCheck), $this->deliveryOptionsFactory->create($carrier, $country, 'package', $type, [
                'signature'     => (bool) mt_rand(0, 1),
                'onlyRecipient' => (bool) mt_rand(0, 1),
            ], $date)];
        }

        if ($country === 'BE') {
            $carrier = mt_rand(1, 10) <= 3 ? 'dhlforyou' : 'postnl';
            $options = $carrier === 'postnl' ? ['signature' => (bool) mt_rand(0, 1)] : [];

            return [$this->packageItems($country, true), $this->deliveryOptionsFactory->create($carrier, $country, 'package', 'standard', $options, $date)];
        }

        return [$this->packageItems($country, true), $this->deliveryOptionsFactory->create('postnl', $country, 'package', 'standard', [], $date)];
    }

    /**
     * One to three package products, more until the subtotal reaches $minimum. Age check only to NL and only when $ageCheck;
     * a product that disables the delivery options never goes in a MyParcel order.
     *
     * @return array<int, array{0: string, 1: int}>
     */
    private function packageItems(string $country, bool $myParcel, float $minimum = 0.0, bool $ageCheck = true): array
    {
        $pool = array_values($this->products(fn (array $p) => ! $this->isMailbox($p)
            && empty($p['attributes']['myparcel_digital_stamp'])
            && (($ageCheck && $country === 'NL') || ($p['attributes']['myparcel_age_check'] ?? '0') !== '1')
            && ! ($myParcel && ! empty($p['attributes']['myparcel_disable_checkout']))));

        $items = [];
        $total = 0.0;
        $lines = mt_rand(1, 3);
        while (count($items) < $lines || ($total < $minimum && count($items) < count($pool))) {
            $product = $pool[mt_rand(0, count($pool) - 1)];
            if (isset($items[$product['sku']])) {
                continue;
            }
            $qty                     = mt_rand(1, 4) === 1 ? 2 : 1;
            $items[$product['sku']]  = [$product['sku'], $qty];
            $total                  += $product['price'] * $qty;
        }

        return array_values($items);
    }

    /** A delivery day 1 to 3 days after the order, Tuesday to Friday (Monday delivery is off by default). */
    private function deliveryDate(int $createdAt): string
    {
        $time = $createdAt + mt_rand(1, 3) * self::DAY;
        while (! in_array((int) gmdate('N', $time), [2, 3, 4, 5], true)) {
            $time += self::DAY;
        }

        return gmdate('Y-m-d', $time);
    }

    /** Mailbox fit 1 to 100, no age check (a mailbox cannot have it), not hidden from the checkout. */
    private function isMailbox(array $product): bool
    {
        $fit = (int) ($product['attributes']['myparcel_fit_in_mailbox'] ?? 0);

        return $fit >= 1 && $fit <= 100
            && ($product['attributes']['myparcel_age_check'] ?? '0') !== '1'
            && empty($product['attributes']['myparcel_disable_checkout']);
    }

    private function products(callable $filter): array
    {
        return array_values(array_filter($this->fixtures->products(), $filter));
    }

    private function guest(int $index): array
    {
        return [
            'firstname' => $this->pick(self::FIRSTNAMES),
            'lastname'  => $this->pick(self::LASTNAMES),
            'email'     => sprintf('guest-%03d@example.com', $index + 1),
        ];
    }

    /** @param array<string, int> $weights */
    private function weighted(array $weights): string
    {
        $roll = mt_rand(1, array_sum($weights));
        foreach ($weights as $value => $weight) {
            if (($roll -= $weight) <= 0) {
                return (string) $value;
            }
        }

        return (string) array_key_last($weights);
    }

    private function pick(array $values): mixed
    {
        return $values[mt_rand(0, count($values) - 1)];
    }

    /** Fisher-Yates on mt_rand, so the order depends only on the seed. */
    private function shuffle(array $values): array
    {
        $values = array_values($values);
        for ($i = count($values) - 1; $i > 0; $i--) {
            $j = mt_rand(0, $i);
            [$values[$i], $values[$j]] = [$values[$j], $values[$i]];
        }

        return $values;
    }
}
