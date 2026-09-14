# ==============================================================================
# Tier 3 parts: C1-C3 - entity+theme, category+keyword, entity+category pairs.
# ==============================================================================
# Combination 1: Entity + Theme
# ------------------------------------------------------------------------------
test_start "T3-01-01" "Combination: Entity 'Riven' + Theme 'Anthem Anatheme & Wish-Bargains'"
COUNT=$(exec_filter "Riven" "" "Anthem Anatheme & Wish-Bargains" "")
if [[ "${COUNT}" -gt 0 ]]; then
    test_pass "T3-01-01" "Found ${COUNT} records for Riven + Anthem Anatheme"
else
    test_fail "T3-01-01" "Riven + Anthem Anatheme failed (count: ${COUNT})"
fi

test_start "T3-01-02" "Combination: Entity 'Taranis' + Theme 'Parentage & The Uncorrupted Clutch'"
COUNT=$(exec_filter "Taranis" "" "Parentage & The Uncorrupted Clutch" "")
if [[ "${COUNT}" -gt 0 ]]; then
    test_pass "T3-01-02" "Found ${COUNT} records for Taranis + Uncorrupted Clutch"
else
    test_fail "T3-01-02" "Taranis + Uncorrupted Clutch failed (count: ${COUNT})"
fi

test_start "T3-01-03" "Combination: Entity 'Hefnd' + Theme 'Vengeance & Twisted Desires'"
COUNT=$(exec_filter "Hefnd" "" "Vengeance & Twisted Desires" "")
if [[ "${COUNT}" -gt 0 ]]; then
    test_pass "T3-01-03" "Found ${COUNT} records for Hefnd + Vengeance"
else
    test_fail "T3-01-03" "Hefnd + Vengeance failed (count: ${COUNT})"
fi

test_start "T3-01-04" "Combination: Entity 'Great Hunt' + Theme 'The Great Hunt & Extinction'"
COUNT=$(exec_filter "Great Hunt" "" "The Great Hunt & Extinction" "")
if [[ "${COUNT}" -gt 0 ]]; then
    test_pass "T3-01-04" "Found ${COUNT} records for Great Hunt + Extinction"
else
    test_fail "T3-01-04" "Great Hunt + Extinction failed (count: ${COUNT})"
fi

test_start "T3-01-05" "Combination: Entity 'General Ahamkara' + Theme 'Fourth-Wall Transcendence'"
COUNT=$(exec_filter "Ahamkara" "" "Fourth-Wall" "")
if [[ "${COUNT}" -gt 0 ]]; then
    test_pass "T3-01-05" "Found ${COUNT} records for Ahamkara + Fourth-Wall"
else
    test_fail "T3-01-05" "Ahamkara + Fourth-Wall failed (count: ${COUNT})"
fi

# ------------------------------------------------------------------------------
# Combination 2: Keyword + Category
# ------------------------------------------------------------------------------
test_start "T3-02-01" "Combination: Category 'exotic_armor' + Keyword 'Bones'"
COUNT=$(exec_filter "" "exotic_armor" "" "Bones")
if [[ "${COUNT}" -gt 0 ]]; then
    test_pass "T3-02-01" "Found ${COUNT} records for exotic_armor + 'Bones'"
else
    test_fail "T3-02-01" "exotic_armor + 'Bones' failed (count: ${COUNT})"
fi

test_start "T3-02-02" "Combination: Category 'exotic_weapon' + Keyword 'Whisper'"
COUNT=$(exec_filter "" "exotic_weapon" "" "Whisper")
if [[ "${COUNT}" -ge 0 ]]; then
    test_pass "T3-02-02" "Executed exotic_weapon + 'Whisper' (count: ${COUNT})"
else
    test_fail "T3-02-02" "exotic_weapon + 'Whisper' failed"
fi

test_start "T3-02-03" "Combination: Category 'wall_of_wishes' + Keyword 'cherish'"
COUNT=$(exec_filter "" "wall_of_wishes" "" "cherish")
if [[ "${COUNT}" -ge 1 ]]; then
    test_pass "T3-02-03" "Found 15th Wish with keyword 'cherish' (count: ${COUNT})"
else
    test_fail "T3-02-03" "wall_of_wishes + 'cherish' failed (count: ${COUNT})"
fi

test_start "T3-02-04" "Combination: Category 'lore_book' + Keyword 'Sjur'"
COUNT=$(exec_filter "" "lore_book" "" "Sjur")
if [[ "${COUNT}" -gt 0 ]]; then
    test_pass "T3-02-04" "Found ${COUNT} records for lore_book + 'Sjur'"
else
    test_fail "T3-02-04" "lore_book + 'Sjur' failed (count: ${COUNT})"
fi

test_start "T3-02-05" "Combination: Category 'grimoire_card' + Keyword 'extinction'"
COUNT=$(exec_filter "" "grimoire_card" "" "extinction")
if [[ "${COUNT}" -gt 0 ]]; then
    test_pass "T3-02-05" "Found ${COUNT} records for grimoire_card + 'extinction'"
else
    test_fail "T3-02-05" "grimoire_card + 'extinction' failed (count: ${COUNT})"
fi

# ------------------------------------------------------------------------------
# Combination 3: Entity + Category
# ------------------------------------------------------------------------------
test_start "T3-03-01" "Combination: Entity 'Hefnd' + Category 'quest_lore' or Warlord's Ruin"
COUNT=$(exec_filter "Hefnd" "quest_lore" "" "")
if [[ "${COUNT}" -ge 0 ]]; then
    test_pass "T3-03-01" "Executed Hefnd + quest_lore (count: ${COUNT})"
else
    test_fail "T3-03-01" "Hefnd + quest_lore failed"
fi

test_start "T3-03-02" "Combination: Entity 'Riven' + Category 'raid_armor'"
COUNT=$(exec_filter "Riven" "raid_armor" "" "")
if [[ "${COUNT}" -ge 5 ]]; then
    test_pass "T3-03-02" "Found ${COUNT} records for Riven + raid_armor (Warlock set)"
else
    test_fail "T3-03-02" "Riven + raid_armor failed (count: ${COUNT})"
fi

test_start "T3-03-03" "Combination: Entity 'Riven' + Category 'wall_of_wishes'"
COUNT=$(exec_filter "Riven" "wall_of_wishes" "" "")
if [[ "${COUNT}" -ge 1 ]]; then
    test_pass "T3-03-03" "Found ${COUNT} records for Riven + wall_of_wishes"
else
    test_fail "T3-03-03" "Riven + wall_of_wishes failed (count: ${COUNT})"
fi

test_start "T3-03-04" "Combination: Entity 'Taranis' + Category 'lore_book'"
COUNT=$(exec_filter "Taranis" "lore_book" "" "")
if [[ "${COUNT}" -ge 4 ]]; then
    test_pass "T3-03-04" "Found ${COUNT} records for Taranis + lore_book (Gifts & Bargains)"
else
    test_fail "T3-03-04" "Taranis + lore_book failed (count: ${COUNT})"
fi

test_start "T3-03-05" "Combination: Entity 'Eao' + Category 'exotic_armor'"
COUNT=$(exec_filter "Eao" "exotic_armor" "" "")
if [[ "${COUNT}" -ge 1 ]]; then
    test_pass "T3-03-05" "Found ${COUNT} records for Eao + exotic_armor (Bones of Eao)"
else
    test_fail "T3-03-05" "Eao + exotic_armor failed (count: ${COUNT})"
fi

# ------------------------------------------------------------------------------
# Combination 4: Chronology + Theme
# ------------------------------------------------------------------------------
test_start "T3-04-01" "Combination: Chronology 'The Great Ahamkara Hunt' + Theme 'The Great Hunt & Extinction'"
COUNT=$(python3 -c "
import json
with open('${CORPUS_JSONL}') as f:
    records = [json.loads(l) for l in f if l.strip()]
print(len([r for r in records if r.get('chronology') == 'The Great Ahamkara Hunt' and r.get('theme') == 'The Great Hunt & Extinction']))
" 2>/dev/null || echo 0)
if [[ "${COUNT}" -ge 10 ]]; then
    test_pass "T3-04-01" "Found ${COUNT} records for Hunt Chronology + Hunt Theme"
else
    test_fail "T3-04-01" "Hunt Chronology + Hunt Theme failed (count: ${COUNT})"
fi

test_start "T3-04-02" "Combination: Chronology 'Forsaken' + Theme 'The Wall of Wishes & Coded Desire'"
COUNT=$(python3 -c "
import json
with open('${CORPUS_JSONL}') as f:
    records = [json.loads(l) for l in f if l.strip()]
print(len([r for r in records if 'Forsaken' in r.get('chronology', '') and 'Wall of Wishes' in r.get('theme', '')]))
" 2>/dev/null || echo 0)
if [[ "${COUNT}" -ge 15 ]]; then
    test_pass "T3-04-02" "Found ${COUNT} records for Forsaken + Wall of Wishes"
else
    test_fail "T3-04-02" "Forsaken + Wall of Wishes failed (count: ${COUNT})"
fi

test_start "T3-04-03" "Combination: Chronology 'Season of the Wish' + Theme 'Parentage & The Uncorrupted Clutch'"
COUNT=$(python3 -c "
import json
with open('${CORPUS_JSONL}') as f:
    records = [json.loads(l) for l in f if l.strip()]
print(len([r for r in records if 'Season of the Wish' in r.get('chronology', '') and 'Uncorrupted Clutch' in r.get('theme', '')]))
" 2>/dev/null || echo 0)
if [[ "${COUNT}" -ge 4 ]]; then
    test_pass "T3-04-03" "Found ${COUNT} records for Season of the Wish + Clutch"
else
    test_fail "T3-04-03" "Season of the Wish + Clutch failed (count: ${COUNT})"
fi

