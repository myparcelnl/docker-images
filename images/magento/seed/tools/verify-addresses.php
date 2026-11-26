<?php

declare(strict_types=1);

/**
 * Dev tool: checks every address in fixtures/addresses.json against a public source.
 * NL uses the PDOK locatieserver (BAG), other countries use OpenStreetMap Nominatim (1 request per second).
 * Prints OK or FAIL per address and exits 1 on any FAIL. Run: php tools/verify-addresses.php
 */

function fetchJson(string $url): array
{
    $context = stream_context_create(['http' => ['header' => "User-Agent: docker-images-seed-verify\r\n", 'timeout' => 20]]);
    $body = @file_get_contents($url, false, $context);

    return false === $body ? [] : (json_decode($body, true) ?: []);
}

function same(string $a, string $b): bool
{
    $clean = fn (string $s) => preg_replace('/[^a-z0-9]/', '', strtolower(iconv('UTF-8', 'ASCII//TRANSLIT', $s)));

    return $clean($a) === $clean($b);
}

function verifyNl(array $address): bool
{
    $query = sprintf('%s %s', $address['postcode'], $address['house_number']);
    $docs = fetchJson('https://api.pdok.nl/bzk/locatieserver/search/v3_1/free?' . http_build_query(['q' => $query, 'fq' => 'type:adres', 'rows' => 1]))['response']['docs'] ?? [];

    return isset($docs[0])
        && same($docs[0]['straatnaam'] ?? '', $address['street'][0])
        && same($docs[0]['woonplaatsnaam'] ?? '', $address['city']);
}

/** @return array{0: bool, 1: string} ok flag and optional note (WARN when OSM lacks a house number) */
function verifyNominatim(array $address): array
{
    sleep(1);
    $hit = fetchJson('https://nominatim.openstreetmap.org/search?' . http_build_query([
        'format' => 'json',
        'addressdetails' => 1,
        'street' => $address['house_number'] . ' ' . $address['street'][0],
        'city' => $address['city'],
        'postalcode' => $address['postcode'],
        'countrycodes' => strtolower($address['country']),
        'limit' => 1,
    ]))[0]['address'] ?? null;

    if (null === $hit) {
        return [false, 'no result'];
    }

    $postcode = fn (string $p) => strtoupper(preg_replace('/\s+/', '', $p));

    if ($postcode($hit['postcode'] ?? '') !== $postcode($address['postcode'])) {
        return [false, 'postcode ' . ($hit['postcode'] ?? 'missing')];
    }

    if (! same($hit['road'] ?? $hit['pedestrian'] ?? '', $address['street'][0])) {
        return [false, 'street ' . ($hit['road'] ?? $hit['pedestrian'] ?? 'missing')];
    }

    if (! isset($hit['house_number'])) {
        return [true, 'WARN no house number in OSM'];
    }

    return same($hit['house_number'], $address['house_number']) ? [true, ''] : [false, 'house number ' . $hit['house_number']];
}

$addresses = json_decode(file_get_contents(__DIR__ . '/../fixtures/addresses.json'), true, 512, JSON_THROW_ON_ERROR);
$failed = 0;

foreach ($addresses as $address) {
    [$ok, $note] = 'NL' === $address['country'] ? [verifyNl($address), ''] : verifyNominatim($address);
    $failed += $ok ? 0 : 1;
    printf("%s %s: %s %s, %s %s (%s) %s\n", $ok ? 'OK  ' : 'FAIL', $address['id'], $address['street'][0], $address['house_number'], $address['postcode'], $address['city'], $address['label'], $note);
}

exit($failed > 0 ? 1 : 0);
