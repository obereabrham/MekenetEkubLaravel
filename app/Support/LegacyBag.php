<?php
namespace App\Support;

use ArrayAccess;

class LegacyBag implements ArrayAccess
{
    public function __construct(private array $values = []) {}
    public function get(string $key, mixed $default = null, mixed $type = null): mixed
    {
        $value = $this->values[$key] ?? $default;
        return match ($type) { 'int' => $value === null ? null : (int) $value, 'float' => $value === null ? null : (float) $value, 'bool' => (bool) $value, default => $value };
    }
    public function offsetExists(mixed $offset): bool { return isset($this->values[$offset]); }
    public function offsetGet(mixed $offset): mixed { return $this->values[$offset] ?? null; }
    public function offsetSet(mixed $offset, mixed $value): void { $this->values[$offset] = $value; }
    public function offsetUnset(mixed $offset): void { unset($this->values[$offset]); }
}