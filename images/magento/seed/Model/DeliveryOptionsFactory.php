<?php

declare(strict_types=1);

namespace MyParcelNL\DevSeed\Model;

/**
 * Builds the delivery options that the checkout stores in myparcel_delivery_options, in the shape of the
 * delivery-options 7 "update" event: {carrier, date? ("Y-m-d H:i:s.u"), deliveryType, isPickup, packageType, shipmentOptions: {signature?, onlyRecipient?, priorityDelivery?: bool}}.
 * Refuses pickup (needs a real location code from the API) and options outside the carrier rules of the seed.
 */
class DeliveryOptionsFactory
{
    public const CARRIERS          = ['postnl', 'dhlforyou'];
    public const PACKAGE_TYPES     = ['package', 'mailbox', 'digital_stamp'];
    public const DELIVERY_TYPES    = ['standard', 'morning', 'evening'];
    public const SHIPMENT_OPTIONS  = ['signature', 'onlyRecipient', 'priorityDelivery'];
    private const NL_ONLY          = ['morning', 'evening', 'mailbox', 'digital_stamp'];

    /**
     * @param array<string, bool> $shipmentOptions camelCase keys, as the frontend sends them
     * @param string|null         $date            Y-m-d, or null when the checkout shows no delivery date
     */
    public function create(
        string $carrier,
        string $country,
        string $packageType,
        string $deliveryType,
        array $shipmentOptions,
        ?string $date
    ): array {
        $this->assertIn('carrier', $carrier, self::CARRIERS);
        $this->assertIn('package type', $packageType, self::PACKAGE_TYPES);
        $this->assertIn('delivery type', $deliveryType, self::DELIVERY_TYPES);

        foreach ([$packageType, $deliveryType] as $value) {
            if ($country !== 'NL' && in_array($value, self::NL_ONLY, true)) {
                throw new \InvalidArgumentException(sprintf('"%s" is only allowed for NL, not %s', $value, $country));
            }
        }

        foreach ($shipmentOptions as $option => $value) {
            $this->assertIn('shipment option', (string) $option, self::SHIPMENT_OPTIONS);
            $shipmentOptions[$option] = (bool) $value;
        }

        $options = ['carrier' => $carrier];
        // Without a date the checkout stores no date key. A null date gives the export a drop-off day.
        if ($date !== null) {
            $options['date'] = $date . ' 00:00:00.000000';
        }

        return $options + [
            'deliveryType'    => $deliveryType,
            'isPickup'        => false,
            'packageType'     => $packageType,
            // the frontend sends an object, also when it is empty
            'shipmentOptions' => $shipmentOptions ?: new \stdClass(),
        ];
    }

    private function assertIn(string $name, string $value, array $allowed): void
    {
        if (! in_array($value, $allowed, true)) {
            throw new \InvalidArgumentException(sprintf('Unknown %s "%s"', $name, $value));
        }
    }
}
