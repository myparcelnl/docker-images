<?php

declare(strict_types=1);

require_once __DIR__ . '/MagentoStubs.php';

// Pest only auto-loads Test/Pest.php with --test-directory=Test, so phpunit.xml.dist loads this file as bootstrap.
// Keep it to plain helper functions: no uses() calls.

/** @param class-string $class */
function newInstanceWithoutConstructor(string $class): object
{
    return (new ReflectionClass($class))->newInstanceWithoutConstructor();
}

function setPrivateProperty(object $object, string $property, mixed $value): void
{
    $reflection = new ReflectionProperty($object, $property);
    $reflection->setAccessible(true);
    $reflection->setValue($object, $value);
}

function invokePrivateMethod(object $object, string $method, array $arguments = []): mixed
{
    $reflection = new ReflectionMethod($object, $method);
    $reflection->setAccessible(true);

    return $reflection->invokeArgs($object, $arguments);
}
