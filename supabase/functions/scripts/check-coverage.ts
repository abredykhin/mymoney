/**
 * Parses LCOV coverage report and checks if coverage meets minimum threshold
 * Usage: deno run --allow-read scripts/check-coverage.ts
 */

const COVERAGE_THRESHOLD = 80; // Minimum 80% coverage required

async function main() {
  try {
    const lcovContent = await Deno.readTextFile('./coverage.lcov');

    // Parse LCOV format
    // LF = lines found, LH = lines hit
    const linesFound = lcovContent.match(/LF:(\d+)/g);
    const linesHit = lcovContent.match(/LH:(\d+)/g);

    if (!linesFound || !linesHit) {
      console.error('❌ Could not parse coverage data');
      Deno.exit(1);
    }

    const totalLines = linesFound
      .map(l => parseInt(l.split(':')[1]))
      .reduce((a, b) => a + b, 0);

    const totalHit = linesHit
      .map(l => parseInt(l.split(':')[1]))
      .reduce((a, b) => a + b, 0);

    const coveragePercent = (totalHit / totalLines) * 100;

    console.log(`\n📊 Coverage Report:`);
    console.log(`   Lines: ${totalHit}/${totalLines}`);
    console.log(`   Coverage: ${coveragePercent.toFixed(2)}%`);
    console.log(`   Threshold: ${COVERAGE_THRESHOLD}%
`);

    if (coveragePercent < COVERAGE_THRESHOLD) {
      console.error(`❌ Coverage ${coveragePercent.toFixed(2)}% is below ${COVERAGE_THRESHOLD}% threshold`);
      Deno.exit(1);
    }

    console.log(`✅ Coverage meets ${COVERAGE_THRESHOLD}% threshold`);
    Deno.exit(0);

  } catch (error) {
    console.error('❌ Error reading coverage file:', error.message);
    console.error('   Make sure to run: deno task test:coverage && deno task coverage');
    Deno.exit(1);
  }
}

main();
