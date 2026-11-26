<?php

declare(strict_types=1);

namespace MyParcelNL\DevSeed\Model;

/**
 * Reads the JSON fixtures of the seed (products, addresses, customers, delivery costs matrix).
 * Plain arrays, no Magento dependency, so unit tests run on the host.
 */
class Fixtures
{
    private string $dir;

    // No __DIR__ default: compiled DI would keep the path of the build
    public function __construct(?string $dir = null)
    {
        $this->dir = $dir ?? __DIR__ . '/../fixtures';
    }

    /** @return array<int, array{sku: string, name: string, weight_grams: int, price: float, hs_code: string, attributes: array<string, mixed>}> */
    public function products(): array
    {
        return $this->load('products');
    }

    /** @return array<int, array<string, mixed>> */
    public function addresses(): array
    {
        return $this->load('addresses');
    }

    /** @return array<int, array<string, mixed>> */
    public function customers(): array
    {
        return $this->load('customers');
    }

    /** @return array<int, array{name: string, price: float|int, conditions: array<int, array{type: string, value: mixed}>}> */
    public function deliveryCosts(): array
    {
        return $this->load('delivery-costs');
    }

    private function load(string $name): array
    {
        $path = sprintf('%s/%s.json', $this->dir, $name);

        if (! is_file($path)) {
            throw new \RuntimeException(sprintf('Fixture file not found: %s', $path));
        }

        return json_decode(file_get_contents($path), true, 512, JSON_THROW_ON_ERROR);
    }
}
