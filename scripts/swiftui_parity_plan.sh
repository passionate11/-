#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLAN_FILE="$ROOT_DIR/docs/swiftui-migration-plan.json"
PARITY_FILE="$ROOT_DIR/docs/swiftui-parity-matrix.json"
CONTRACT_FILE="$ROOT_DIR/docs/settings-contract.json"
SWIFT_FILE="$ROOT_DIR/Sources/EyeRest/main.swift"
OBJC_FILE="$ROOT_DIR/Sources/EyeRestObjC/main.m"
STRICT=0

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'HELP'
Usage:
  scripts/swiftui_parity_plan.sh
  scripts/swiftui_parity_plan.sh --strict

Prints a read-only SwiftUI migration phase plan and validates that every required
parity gap is assigned to exactly one migration phase. It does not launch the app.
HELP
  exit 0
fi

if [[ "${1:-}" == "--strict" ]]; then
  STRICT=1
fi

if [[ "$(uname -s)" == "Darwin" ]]; then
  [[ "${LC_ALL:-}" == "C.UTF-8" ]] && export LC_ALL="en_US.UTF-8"
  [[ "${LC_CTYPE:-}" == "C.UTF-8" ]] && export LC_CTYPE="en_US.UTF-8"
  [[ "${LANG:-}" == "C.UTF-8" || -z "${LANG:-}" ]] && export LANG="en_US.UTF-8"
fi

if ! command -v ruby >/dev/null 2>&1; then
  echo "swiftui_parity_plan: ruby is required to read JSON" >&2
  [[ "$STRICT" == "1" ]] && exit 1
  exit 0
fi

PLAN_FILE="$PLAN_FILE" \
PARITY_FILE="$PARITY_FILE" \
CONTRACT_FILE="$CONTRACT_FILE" \
SWIFT_FILE="$SWIFT_FILE" \
OBJC_FILE="$OBJC_FILE" \
STRICT="$STRICT" \
ruby <<'RUBY'
require "json"

plan_file = ENV.fetch("PLAN_FILE")
parity_file = ENV.fetch("PARITY_FILE")
contract_file = ENV.fetch("CONTRACT_FILE")
swift_file = ENV.fetch("SWIFT_FILE")
objc_file = ENV.fetch("OBJC_FILE")
strict = ENV["STRICT"] == "1"

failures = 0
warnings = 0

def section(title)
  puts
  puts "== #{title} =="
end

def kv(key, value)
  value = "-" if value.nil? || value.to_s.empty?
  printf "  %-32s %s\n", "#{key}:", value
end

ok = ->(label) { kv(label, "ok") }

emit_fail = lambda do |label, detail|
  $failures_ref[:value] += 1
  kv(label, "fail - #{detail}")
end

$warnings_ref = { value: 0 }
$failures_ref = { value: 0 }

read_json = lambda do |path, label|
  unless File.file?(path)
    emit_fail.call(label, "missing #{path}")
    next nil
  end
  begin
    JSON.parse(File.read(path))
  rescue JSON::ParserError => error
    emit_fail.call(label, error.message)
    nil
  end
end

section("Sources")
[[plan_file, "Migration plan"], [parity_file, "Parity matrix"], [contract_file, "Settings contract"], [swift_file, "SwiftUI draft"], [objc_file, "Objective-C app"]].each do |path, label|
  File.file?(path) ? ok.call(label) : emit_fail.call(label, "missing #{path}")
end

plan = read_json.call(plan_file, "Plan JSON")
parity = read_json.call(parity_file, "Parity JSON")
contract = read_json.call(contract_file, "Contract JSON")

if plan && parity && contract
  section("Plan Contract")
  plan["migrationStatus"] == "prototype only" ? ok.call("Migration status") : emit_fail.call("Migration status", "must stay prototype only")
  plan["switchGuard"].to_s.include?("Keep Objective-C/AppKit") ? ok.call("Switch guard") : emit_fail.call("Switch guard", "must keep AppKit shipping guard")
  plan["sourceParityMatrix"] == "docs/swiftui-parity-matrix.json" ? ok.call("Parity matrix link") : emit_fail.call("Parity matrix link", "wrong sourceParityMatrix")
  plan["sourceSettingsContract"] == "docs/settings-contract.json" ? ok.call("Settings contract link") : emit_fail.call("Settings contract link", "wrong sourceSettingsContract")
  contract["storageModel"] == "per-key UserDefaults" ? ok.call("Settings storage model") : emit_fail.call("Settings storage model", "unexpected storage model")

  phases = Array(plan["phases"])
  parity_features = Array(parity["features"])
  required_ids = parity_features.select { |feature| feature["requiredBeforeSwitch"] }.map { |feature| feature["id"] }
  assigned_ids = phases.flat_map { |phase| Array(phase["featureIds"]) }
  duplicate_ids = assigned_ids.group_by(&:itself).select { |_id, values| values.length > 1 }.keys
  missing_ids = required_ids - assigned_ids
  extra_ids = assigned_ids - required_ids

  section("Phase Coverage")
  kv("Phase count", phases.length)
  phases.length == 4 ? ok.call("Expected phase count") : emit_fail.call("Expected phase count", "expected 4 phases")
  kv("Required parity features", required_ids.length)
  required_ids.length == 10 ? ok.call("Required feature count") : emit_fail.call("Required feature count", "expected 10 required features")
  missing_ids.empty? ? ok.call("Missing feature assignments") : emit_fail.call("Missing feature assignments", missing_ids.join(", "))
  duplicate_ids.empty? ? ok.call("Duplicate feature assignments") : emit_fail.call("Duplicate feature assignments", duplicate_ids.join(", "))
  extra_ids.empty? ? ok.call("Unknown feature assignments") : emit_fail.call("Unknown feature assignments", extra_ids.join(", "))

  orders = phases.map { |phase| phase["order"].to_i }
  orders == orders.sort && orders == (1..phases.length).to_a ? ok.call("Phase order") : emit_fail.call("Phase order", "orders must be contiguous and sorted")
  all_required = phases.all? { |phase| phase["requiredBeforeSwitch"] == true }
  all_required ? ok.call("Required-before-switch phases") : emit_fail.call("Required-before-switch phases", "all phases must be required")

  section("Port Order")
  phases.sort_by { |phase| phase["order"].to_i }.each do |phase|
    feature_ids = Array(phase["featureIds"])
    feature_labels = parity_features.select { |feature| feature_ids.include?(feature["id"]) }.map { |feature| feature["label"] }
    kv("Phase #{phase["order"]}", "#{phase["id"]} · #{phase["title"]}")
    kv("  Feature ids", feature_ids.join(", "))
    kv("  Feature labels", feature_labels.join(", "))
    kv("  Next port", phase["recommendedNextPort"])
  end

  section("Recommendation")
  kv("Plan status", "prototype only")
  kv("Next phase", phases.sort_by { |phase| phase["order"].to_i }.first&.fetch("id", nil))
  puts "  Next:"
  puts "  - Keep Objective-C/AppKit as the shipping app."
  puts "  - Start with settings-contract-foundation before timers, automation, or release support."
  puts "  - Re-run swiftui_migration_readiness.sh and settings_contract_readiness.sh after each port phase."
end

section("Summary")
failures = $failures_ref[:value]
warnings = $warnings_ref[:value]
kv("Failures", failures)
kv("Warnings", warnings)
kv("Readiness", failures.zero? ? "SwiftUI parity plan assessed" : "attention needed")

exit 1 if strict && failures.positive?
RUBY
