<?php

declare(strict_types=1);

namespace MyParcelNL\DevSeed\Model;

/**
 * Tells observers that the seed places the current order. Shared instance (DI default).
 * placeOrder() loads the quote again from the database, so a flag on the quote would not survive.
 */
class SeedOrderContext
{
    private bool $active = false;

    public function run(callable $callback): mixed
    {
        $this->active = true;
        try {
            return $callback();
        } finally {
            $this->active = false;
        }
    }

    public function isActive(): bool
    {
        return $this->active;
    }
}
