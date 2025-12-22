// Generate hash collisions for MoonBit's xxHash32 with seed=0
// This simulates what an attacker would need to do

// xxHash32 constants (same as MoonBit)
const GPRIME1 = 0x9e3779b1 | 0;
const GPRIMES2 = 0x85ebca77 | 0;  // Note: typo in MoonBit is GPRIMES2
const GPRIME3 = 0xc2b2ae3d | 0;
const GPRIME4 = 0x27d4eb2f | 0;
const GPRIME5 = 0x165667b1 | 0;

// Rotate left
function rotl(x, r) {
    return ((x << r) | (x >>> (32 - r))) | 0;
}

// MoonBit's xxHash32 implementation for strings
function xxhash32_moonbit(str, seed = 0) {
    // Initialize: acc = seed + GPRIME5
    let acc = ((seed | 0) + GPRIME5) | 0;

    // For each character: combine_uint
    for (let i = 0; i < str.length; i++) {
        const charCode = str.charCodeAt(i);
        // combine_uint does: acc += 4, then consume4
        acc = (acc + 4) | 0;
        // consume4: acc = rotl(acc + input * GPRIME3, 17) * GPRIME4
        acc = Math.imul(rotl((acc + Math.imul(charCode, GPRIME3)) | 0, 17), GPRIME4) | 0;
    }

    // Finalize (avalanche)
    acc = acc ^ (acc >>> 15);
    acc = Math.imul(acc, GPRIMES2) | 0;
    acc = acc ^ (acc >>> 13);
    acc = Math.imul(acc, GPRIME3) | 0;
    acc = acc ^ (acc >>> 16);

    return acc;
}

// Main
console.log("=== Hash Collision Generation Test ===\n");

// Test hash function matches MoonBit output
const testCases = [
    { str: "a", expected: 2079483668 },
    { str: "b", expected: 1259778150 },
    { str: "abc", expected: -771846975 },
    { str: "aa", expected: -1424816882 },
    { str: "", expected: 46947589 },
];

console.log("Verifying hash function against MoonBit output:");
let allMatch = true;
for (const { str, expected } of testCases) {
    const actual = xxhash32_moonbit(str, 0);
    const match = actual === expected;
    allMatch = allMatch && match;
    console.log(`  xxhash32("${str}") = ${actual} ${match ? '✓' : `✗ (expected ${expected})`}`);
}

if (!allMatch) {
    console.log("\n⚠️  Hash mismatch detected - implementation differs from MoonBit");
    process.exit(1);
}

console.log("\n✓ Hash function matches MoonBit implementation");

// Find collisions by brute force
function findCollisions(targetHash, maxAttempts = 50_000_000) {
    const collisions = [];
    let attempts = 0;

    // Try short strings first (more efficient)
    const charset = 'abcdefghijklmnopqrstuvwxyz0123456789';

    for (let len = 1; len <= 6 && collisions.length < 100; len++) {
        const indexes = new Array(len).fill(0);

        while (attempts < maxAttempts && collisions.length < 100) {
            // Generate string from indexes
            let s = '';
            for (let i = 0; i < len; i++) {
                s += charset[indexes[i]];
            }

            const hash = xxhash32_moonbit(s, 0);
            if (hash === targetHash) {
                collisions.push(s);
            }

            attempts++;

            // Increment indexes
            let carry = true;
            for (let i = len - 1; i >= 0 && carry; i--) {
                indexes[i]++;
                if (indexes[i] >= charset.length) {
                    indexes[i] = 0;
                } else {
                    carry = false;
                }
            }
            if (carry) break; // Exhausted this length
        }
    }

    return { collisions, attempts };
}

console.log("\nSearching for collisions...");
const startTime = Date.now();

// Try to find collisions with hash of "a"
const targetHash = xxhash32_moonbit("a", 0);
console.log(`Target hash (for "a"): ${targetHash}`);

const result = findCollisions(targetHash, 100_000_000);
const elapsed = (Date.now() - startTime) / 1000;

console.log(`\nAttempts: ${result.attempts.toLocaleString()}`);
console.log(`Time: ${elapsed.toFixed(2)}s`);
console.log(`Hash rate: ${(result.attempts / elapsed / 1_000_000).toFixed(2)} M/s`);
console.log(`Collisions found: ${result.collisions.length}`);
if (result.collisions.length > 0) {
    console.log("Colliding strings:");
    for (const s of result.collisions.slice(0, 10)) {
        console.log(`  "${s}" -> ${xxhash32_moonbit(s, 0)}`);
    }
}

console.log("\n=== Hashdos Feasibility Assessment ===");
const hashRate = result.attempts / elapsed;
console.log(`Hash space: 2^32 = ${(2 ** 32).toLocaleString()}`);
console.log(`Hash rate: ${(hashRate / 1_000_000).toFixed(2)} M/s`);
console.log(`Expected time for 1 collision: ${(2 ** 32 / hashRate).toFixed(1)}s = ${(2 ** 32 / hashRate / 60).toFixed(1)} min`);
console.log(`Expected time for 1000 collisions: ${((2 ** 32 * 1000) / hashRate / 3600).toFixed(1)} hours`);
