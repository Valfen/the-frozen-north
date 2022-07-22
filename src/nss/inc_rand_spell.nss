#include "inc_array"
#include "util_i_math"
#include "nwnx_creature"
#include "nwnx_util"

// This is an include for changing creatures' spells


// Mage purposes - if I had to design typical spellbooks for purposes, they would be...

// Evoker: Heavy focus on doing damage at range
const int RAND_SPELL_ARCANE_EVOKER_SINGLE_TARGET = 0;
// The AoE version is less suitable for NPCs in groups: the AI will hold fire if there are nearby friends
const int RAND_SPELL_ARCANE_EVOKER_AOE = 1;
// Balanced: Ally-friendly damage and control in roughly equal amounts
const int RAND_SPELL_ARCANE_SINGLE_TARGET_BALANCED = 2;
// All about trying to make it difficult for enemies to do anything
const int RAND_SPELL_ARCANE_CONTROLLER = 3;

const int RAND_SPELL_ARCANE_NUMLISTS = 4;

const int RAND_SPELL_DIVINE_START = 100;

const int RAND_SPELL_DIVINE_EVOKER = 100;
const int RAND_SPELL_DIVINE_BUFF_ATTACKS = 101;
const int RAND_SPELL_DIVINE_CONTROLLER = 102;
const int RAND_SPELL_DIVINE_SINGLE_TARGET_BALANCED = 103;
const int RAND_SPELL_DIVINE_HEALER = 104;

const int RAND_SPELL_DIVINE_NUMLISTS = 5;

const int RAND_SPELL_ARCANE_BARD = 200;
const int RAND_SPELL_DIVINE_PALADIN = 300;
const int RAND_SPELL_DIVINE_RANGER = 400;

// How many spellbooks to seed per creature
const int RAND_SPELL_NUM_SPELLBOOKS = 20;

// Generates and saves a random spellbook for oCreature's nClass.
// This should be run only when SeedingSpellbooks() is TRUE due to slow processing.
// nSpellbookType should be a RAND_SPELL_* constant.
// Bards, paladins and rangers should only use their appropriate spellbook constants.
// Load these with LoadSpellbook.
void RandomSpellbookPopulate(int nSpellbookType, object oCreature, int nClass);

void SetRandomSpellWeight(object oCreature, int nSpell, int nWeight);

void SetRandomDomainWeight(object oCreature, int nDomain, int nWeight);

// Loads a spellbook.
// If no index is specified, selects randomly from the creature's resref's available saved books for the given class.
void LoadSpellbook(int nClass, object oCreature=OBJECT_SELF, int nFixedIndex=-1);

// Return TRUE if it's time to seed spellbooks, FALSE if it's not (time to load them instead)
// If it is time, does some initialisation - don't call this more than once for a single class for one creature
int SeedingSpellbooks(int nClass, object oCreature=OBJECT_SELF);


//////////////////

// Set on the module when it's time to seed spellbooks
const string RAND_SPELL_SEEDING_SPELLBOOKS = "RAND_SPELL_SEEDING_SPELLBOOKS";

// Various arrays used in the seeding process
const string RAND_SPELL_SLOTS_REMAINING = "rand_spell_slotsremaining";
const string RAND_SPELL_TEMP_SPELLIDS = "rand_spell_temp_spellids";
const string RAND_SPELL_TEMP_WEIGHTS = "rand_spell_temp_weights";
const string RAND_SPELL_TEMP_SPELL_LEVELS = "rand_spell_temp_spell_levels";
const string RAND_SPELL_TEMP_METAMAGIC = "rand_spell_temp_metamagic";
const string RAND_SPELL_TEMP_DOMAIN = "rand_spell_temp_domain";

struct CategoryWeights
{
    // Eg magic missile, melf's acid arrow
    int nWeightDamagingSingleTarget;
    // Eg chain lightning, firebrand
    int nWeightDamagingAoESelective;
    // Eg fireball, lightning bolt
    int nWeightDamagingAoENonSelective;
    // Eg charm person, blindness/deafness
    int nWeightControlSingleTarget;
    // Eg slow, mass blind/deaf
    int nWeightControlAoESelective;
    // Eg confusion
    int nWeightControlAoENonSelective;
    // Eg haste, boost to casting ability modifier, dispel, spell breaches
    int nWeightOffensiveUtility;
    // Eg remove blindness/deafness
    int nWeightCureConditions;
    // Eg shield, mage armor, spell mantles
    int nWeightDefences;
    int nWeightMeleeAbility;
    
    int nHighestCategoryWeight;
};

void DumpCategoryWeights(struct CategoryWeights cwDump, string sTop)
{
    WriteTimestampedLogEntry("=== CategoryWeights: " + sTop);
    WriteTimestampedLogEntry("nWeightDamagingSingleTarget: " + IntToString(cwDump.nWeightDamagingSingleTarget));
    WriteTimestampedLogEntry("nWeightDamagingAoESelective: " + IntToString(cwDump.nWeightDamagingAoESelective));
    WriteTimestampedLogEntry("nWeightDamagingAoENonSelective: " + IntToString(cwDump.nWeightDamagingAoENonSelective));
    WriteTimestampedLogEntry("nWeightControlSingleTarget: " + IntToString(cwDump.nWeightControlSingleTarget));
    WriteTimestampedLogEntry("nWeightControlAoESelective: " + IntToString(cwDump.nWeightControlAoESelective));
    WriteTimestampedLogEntry("nWeightControlAoENonSelective: " + IntToString(cwDump.nWeightControlAoENonSelective));
    WriteTimestampedLogEntry("nWeightOffensiveUtility: " + IntToString(cwDump.nWeightOffensiveUtility));
    WriteTimestampedLogEntry("nWeightCureConditions: " + IntToString(cwDump.nWeightCureConditions));
    WriteTimestampedLogEntry("nWeightDefences: " + IntToString(cwDump.nWeightDefences));
    WriteTimestampedLogEntry("nWeightMeleeAbility: " + IntToString(cwDump.nWeightMeleeAbility));
    WriteTimestampedLogEntry("nHighestCategoryWeight: " + IntToString(cwDump.nHighestCategoryWeight));
}



struct CategoryWeights _CalculateWeightForSpellAssignment(struct CategoryWeights cwBaseWeights, int nNumSpellsAssigned)
{
    // The aim is to make it so that the first few spells can virtually only be of the highly weighted categories
    // A quick idea of how to do this is to use category-derived weights of max(0, (category weight - scalar))^2
    // Where scalar = (the highest category weight / (2 + number of spells assigned at this level))
    struct CategoryWeights cwOut;
    //DumpCategoryWeights(cwBaseWeights, "Base Weights");
    int nScalar = cwBaseWeights.nHighestCategoryWeight / (2 + nNumSpellsAssigned);
    if (nNumSpellsAssigned >= 2)
    {
        return cwBaseWeights;
    }
    cwOut.nWeightDamagingSingleTarget = max(0, cwBaseWeights.nWeightDamagingSingleTarget - nScalar);
    cwOut.nWeightDamagingAoESelective = max(0, cwBaseWeights.nWeightDamagingAoESelective - nScalar);
    cwOut.nWeightDamagingAoENonSelective = max(0, cwBaseWeights.nWeightDamagingAoENonSelective - nScalar);
    cwOut.nWeightControlSingleTarget = max(0, cwBaseWeights.nWeightControlSingleTarget - nScalar);
    cwOut.nWeightControlAoESelective = max(0, cwBaseWeights.nWeightControlAoESelective - nScalar);
    cwOut.nWeightControlAoENonSelective = max(0, cwBaseWeights.nWeightControlAoENonSelective - nScalar);
    cwOut.nWeightOffensiveUtility = max(0, cwBaseWeights.nWeightOffensiveUtility - nScalar);
    cwOut.nWeightCureConditions = max(0, cwBaseWeights.nWeightCureConditions - nScalar);
    cwOut.nWeightDefences = max(0, cwBaseWeights.nWeightDefences - nScalar);
    cwOut.nWeightMeleeAbility = max(0, cwBaseWeights.nWeightMeleeAbility - nScalar);
    cwOut.nHighestCategoryWeight = max(0, cwBaseWeights.nHighestCategoryWeight - nScalar);
    
    //DumpCategoryWeights(cwOut, "Modified for " + IntToString(nNumSpellsAssigned) + " spells assigned");
    cwOut.nWeightDamagingSingleTarget = cwOut.nWeightDamagingSingleTarget * cwOut.nWeightDamagingSingleTarget;
    cwOut.nWeightDamagingAoESelective = cwOut.nWeightDamagingAoESelective * cwOut.nWeightDamagingAoESelective;
    cwOut.nWeightDamagingAoENonSelective = cwOut.nWeightDamagingAoENonSelective * cwOut.nWeightDamagingAoENonSelective;
    cwOut.nWeightControlSingleTarget = cwOut.nWeightControlSingleTarget * cwOut.nWeightControlSingleTarget;
    cwOut.nWeightControlAoESelective = cwOut.nWeightControlAoESelective * cwOut.nWeightControlAoESelective;
    cwOut.nWeightControlAoENonSelective = cwOut.nWeightControlAoENonSelective * cwOut.nWeightControlAoENonSelective;
    cwOut.nWeightOffensiveUtility = cwOut.nWeightOffensiveUtility * cwOut.nWeightOffensiveUtility;
    cwOut.nWeightCureConditions = cwOut.nWeightCureConditions * cwOut.nWeightCureConditions;
    cwOut.nWeightDefences = cwOut.nWeightDefences * cwOut.nWeightDefences;
    cwOut.nWeightMeleeAbility = cwOut.nWeightMeleeAbility * cwOut.nWeightMeleeAbility;
    cwOut.nHighestCategoryWeight = cwOut.nHighestCategoryWeight * cwOut.nHighestCategoryWeight;
    //DumpCategoryWeights(cwOut, "After squaring, " + IntToString(nNumSpellsAssigned) + " spells assigned");
    return cwOut;
}

int SeedingSpellbooks(int nClass, object oCreature=OBJECT_SELF)
{
    if (GetLocalInt(GetModule(), "RAND_SPELL_SEEDING_SPELLBOOKS"))
    {
        NWNX_Util_SetInstructionLimit(52428888);
        SetCampaignInt("randspellbooks", GetResRef(oCreature) + "_numsbs_" + IntToString(nClass), 0);
        return 1;
    }
    return 0;
}


void _GetAvailableSpellSlots(object oCreature, int nClass)
{
    Array_Clear(RAND_SPELL_SLOTS_REMAINING);
    Array_Resize(RAND_SPELL_SLOTS_REMAINING, 0);
    int nClassAbility;
    if (nClass == CLASS_TYPE_WIZARD)
    {
        nClassAbility = ABILITY_INTELLIGENCE;
    }
    else if (nClass == CLASS_TYPE_SORCERER || nClass == CLASS_TYPE_BARD)
    {
        nClassAbility = ABILITY_CHARISMA;
    }
    else
    {
        nClassAbility = ABILITY_WISDOM;
    }
    string s2da;
    if (nClassAbility == ABILITY_CHARISMA)
    {
        s2da = Get2DAString("classes", "SpellKnownTable", nClass);
    }
    else
    {
        s2da = Get2DAString("classes", "SpellGainTable", nClass);
    }

    if (GetStringLength(s2da) == 0)
    {
        return;
    }
    int nClassLevel = GetLevelByClass(nClass, oCreature);
    int nAbilityModifier = GetAbilityModifier(nClassAbility, oCreature);

    int nLevel;
    for (nLevel=0; nLevel <= 9; nLevel++)
    {
        int nBase = StringToInt(Get2DAString(s2da, "SpellLevel" + IntToString(nLevel), nClassLevel-1));
        if (nBase <= 0) { break; }
        else
        {
            if (nLevel > 0)
            {
                nBase += max(0, 1 + (nAbilityModifier - nLevel)/4);
            }
            Array_PushBack_Int(RAND_SPELL_SLOTS_REMAINING, nBase);
            //WriteTimestampedLogEntry(IntToString(nLevel) + " : " + IntToString(nBase));
        }
    }

    //Array_Debug_Dump(RAND_SPELL_SLOTS_REMAINING, "Num spell slots");
}

void _ClearSpellbook(object oCreature, int nClass)
{
    int nLevel;
    int i;
    if (nClass == CLASS_TYPE_SORCERER || nClass == CLASS_TYPE_BARD)
    {
        for (nLevel=0; nLevel <=9; nLevel++)
        {
            int nNum = NWNX_Creature_GetKnownSpellCount(oCreature, nClass, nLevel);
            for (i=(nNum-1); i>=0; i--)
            {
                int nSpell = NWNX_Creature_GetKnownSpell(oCreature, nClass, nLevel, i);
                NWNX_Creature_RemoveKnownSpell(oCreature, nClass, nLevel, nSpell);
            }
        }
    }
    else
    {
        for (nLevel = 0; nLevel <= 9; nLevel++)
        {
            int nNum = Array_At_Int(RAND_SPELL_SLOTS_REMAINING, nLevel);
            for (i=0; i<nNum; i++)
            {
                struct NWNX_Creature_MemorisedSpell mem = NWNX_Creature_GetMemorisedSpell(oCreature, nClass, nLevel, i);
                mem.ready = 0;
                mem.meta = METAMAGIC_NONE;
                mem.id = SPELL_RESISTANCE;
                NWNX_Creature_SetMemorisedSpell(oCreature, nClass, nLevel, i, mem);
            }
        }
    }
}

string _GetSpells2daColumnForClass(int nClass)
{
    if (nClass == CLASS_TYPE_WIZARD || nClass == CLASS_TYPE_SORCERER)
    {
        return "Wiz_Sorc";
    }
    if (nClass == CLASS_TYPE_CLERIC) { return "Cleric"; }
    if (nClass == CLASS_TYPE_DRUID) { return "Druid"; }
    if (nClass == CLASS_TYPE_PALADIN) { return "Paladin"; }
    if (nClass == CLASS_TYPE_RANGER) { return "Ranger"; }
    if (nClass == CLASS_TYPE_BARD) { return "Bard"; }
    return "";
}

int _GetLevelForSpell(int nSpell, string sClass2da)
{
    string sLevel = Get2DAString("spells", sClass2da, nSpell);
    if (GetStringLength(sLevel) == 0)
    {
        return -1;
    }
    return StringToInt(sLevel);
}

int _GetMetamagicLevelAdjustment(int nMetamagic)
{
    if (nMetamagic == METAMAGIC_EXTEND || nMetamagic == METAMAGIC_STILL || nMetamagic == METAMAGIC_SILENT)
    {
        return 1;
    }
    if (nMetamagic == METAMAGIC_EMPOWER)
    {
        return 2;
    }
    if (nMetamagic == METAMAGIC_MAXIMIZE)
    {
        return 3;
    }
    if (nMetamagic == METAMAGIC_QUICKEN)
    {
        return 4;
    }
    return 0;
}

void _ClearRandomSpellTempArrays()
{
    Array_Clear(RAND_SPELL_TEMP_SPELLIDS);
    Array_Clear(RAND_SPELL_TEMP_WEIGHTS);
    Array_Clear(RAND_SPELL_TEMP_SPELL_LEVELS);
    Array_Clear(RAND_SPELL_TEMP_METAMAGIC);
    Array_Clear(RAND_SPELL_TEMP_DOMAIN);
}

void SetRandomSpellWeight(object oCreature, int nSpell, int nWeight)
{
    // Saving (weight - 1) is deliberate
    // We add 1 when retrieving these, because an unset var in GetLocalInt returns 0 -> becomes 1, normal weighting
    SetLocalInt(oCreature, "rand_spell_weight_" + IntToString(nSpell), nWeight - 1);
}

int _GetRandomSpellWeight(object oCreature, int nSpell)
{
    // Saving (weight - 1) is deliberate
    // We add 1 when retrieving these, because an unset var in GetLocalInt returns 0 -> becomes 1, normal weighting
    return (1 + GetLocalInt(oCreature, "rand_spell_weight_" + IntToString(nSpell)));
}

void SetRandomDomainWeight(object oCreature, int nDomain, int nWeight)
{
    // Saving (weight - 1) is deliberate
    // We add 1 when retrieving these, because an unset var in GetLocalInt returns 0 -> becomes 1, normal weighting
    SetLocalInt(oCreature, "rand_domain_weight_" + IntToString(nDomain), nWeight - 1);
}

int _GetRandomDomainWeight(object oCreature, int nDomain)
{
    // Saving (weight - 1) is deliberate
    // We add 1 when retrieving these, because an unset var in GetLocalInt returns 0 -> becomes 1, normal weighting
    return (1 + GetLocalInt(oCreature, "rand_domain_weight_" + IntToString(nDomain)));
}

int _HasFeatForMetamagic(object oCreature, int nMetamagic)
{
    if (nMetamagic == METAMAGIC_NONE) { return 1; }
    if (nMetamagic & METAMAGIC_EMPOWER && !GetHasFeat(FEAT_EMPOWER_SPELL, oCreature)) { return 0; }
    if (nMetamagic & METAMAGIC_EXTEND && !GetHasFeat(FEAT_EXTEND_SPELL, oCreature)) { return 0; }
    if (nMetamagic & METAMAGIC_MAXIMIZE && !GetHasFeat(FEAT_MAXIMIZE_SPELL, oCreature)) { return 0; }
    if (nMetamagic & METAMAGIC_SILENT && !GetHasFeat(FEAT_SILENCE_SPELL, oCreature)) { return 0; }
    if (nMetamagic & METAMAGIC_STILL && !GetHasFeat(FEAT_STILL_SPELL, oCreature)) { return 0; }
    if (nMetamagic & METAMAGIC_QUICKEN && !GetHasFeat(FEAT_QUICKEN_SPELL, oCreature)) { return 0; }
    return 1;
}

int _GetLevelForSpellWithDomain(int nSpell, int nDomain)
{
    // This could be done via 2da lookups but it's probably really slow
    int nFinalLevel = -1;
    if (nDomain == DOMAIN_AIR)
    {
        if (nSpell == SPELL_CALL_LIGHTNING)
        {
            nFinalLevel = 3;
        }
        else if (nSpell == SPELL_CHAIN_LIGHTNING)
        {
            nFinalLevel = 6;
        }
    }
    else if (nDomain == DOMAIN_ANIMAL)
    {
        if (nSpell == SPELL_CATS_GRACE) { nFinalLevel = 2; }
        else if (nSpell == SPELL_TRUE_SEEING) { nFinalLevel = 3; }
        else if (nSpell == SPELL_POLYMORPH_SELF) { nFinalLevel = 5; }
    }
    else if (nDomain == DOMAIN_DEATH)
    {
        if (nSpell == SPELL_PHANTASMAL_KILLER) { nFinalLevel = 4; }
        else if (nSpell == SPELL_ENERVATION) { nFinalLevel = 5; }
    }
    else if (nDomain == DOMAIN_DESTRUCTION)
    {
        if (nSpell == SPELL_STINKING_CLOUD) { nFinalLevel = 3; }
        else if (nSpell == SPELL_ACID_FOG) { nFinalLevel = 6; }
    }
    else if (nDomain == DOMAIN_EARTH)
    {
        if (nSpell == SPELL_STONESKIN) { nFinalLevel = 4; }
        else if (nSpell == SPELL_ENERGY_BUFFER) { nFinalLevel = 5; }
    }
    else if (nDomain == DOMAIN_EVIL)
    {
        if (nSpell == SPELL_NEGATIVE_ENERGY_RAY) { nFinalLevel = 1; }
        else if (nSpell == SPELL_NEGATIVE_ENERGY_BURST) { nFinalLevel = 3; }
        else if (nSpell == SPELL_ENERVATION) { nFinalLevel = 5; }
    }
    else if (nDomain == DOMAIN_FIRE)
    {
        if (nSpell == SPELL_WALL_OF_FIRE) { nFinalLevel = 4; }
        else if (nSpell == SPELL_ENERGY_BUFFER) { nFinalLevel = 5; }
    }
    else if (nDomain == DOMAIN_GOOD)
    {
        if (nSpell == SPELL_STONESKIN) { nFinalLevel = 4; }
        else if (nSpell == SPELL_LESSER_PLANAR_BINDING) { nFinalLevel = 5; }
    }
    else if (nDomain == DOMAIN_HEALING)
    {
        if (nSpell == SPELL_CURE_SERIOUS_WOUNDS) { nFinalLevel = 2; }
        else if (nSpell == SPELL_HEAL) { nFinalLevel = 5; }
    }
    else if (nDomain == DOMAIN_KNOWLEDGE)
    {
        if (nSpell == SPELL_IDENTIFY) { nFinalLevel = 1; }
        else if (nSpell == SPELL_KNOCK) { nFinalLevel = 2; }
        else if (nSpell == SPELL_CLAIRAUDIENCE_AND_CLAIRVOYANCE) { nFinalLevel = 3; }
        else if (nSpell == SPELL_TRUE_SEEING) { nFinalLevel = 4; }
        else if (nSpell == SPELL_LEGEND_LORE) { nFinalLevel = 6; }
    }
    else if (nDomain == DOMAIN_MAGIC)
    {
        if (nSpell == SPELL_MAGE_ARMOR) { nFinalLevel = 1; }
        else if (nSpell == SPELL_MELFS_ACID_ARROW) { nFinalLevel = 2; }
        else if (nSpell == SPELL_NEGATIVE_ENERGY_BURST) { nFinalLevel = 3; }
        else if (nSpell == SPELL_STONESKIN) { nFinalLevel = 4; }
        else if (nSpell == SPELL_ICE_STORM) { nFinalLevel = 5; }
    }
    else if (nDomain == DOMAIN_PLANT)
    {
        if (nSpell == SPELL_BARKSKIN) { nFinalLevel = 2; }
        else if (nSpell == SPELL_CREEPING_DOOM) { nFinalLevel = 7; }
    }
    else if (nDomain == DOMAIN_PROTECTION)
    {
        if (nSpell == SPELL_MINOR_GLOBE_OF_INVULNERABILITY) { nFinalLevel = 4; }
        else if (nSpell == SPELL_ENERGY_BUFFER) { nFinalLevel = 5; }
    }
    else if (nDomain == DOMAIN_STRENGTH)
    {
        if (nSpell == SPELL_DIVINE_POWER) { nFinalLevel = 3; }
        else if (nSpell == SPELL_STONESKIN) { nFinalLevel = 5; }
    }
    else if (nDomain == DOMAIN_SUN)
    {
        if (nSpell == SPELL_SEARING_LIGHT) { nFinalLevel = 2; }
        else if (nSpell == SPELL_SUNBEAM) { nFinalLevel = 7; }
    }
    else if (nDomain == DOMAIN_TRAVEL)
    {
        if (nSpell == SPELL_ENTANGLE) { nFinalLevel = 1; }
        else if (nSpell == SPELL_WEB) { nFinalLevel = 2; }
        else if (nSpell == SPELL_FREEDOM_OF_MOVEMENT) { nFinalLevel = 3; }
        else if (nSpell == SPELL_SLOW) { nFinalLevel = 4; }
        else if (nSpell == SPELL_HASTE) { nFinalLevel = 5; }
    }
    else if (nDomain == DOMAIN_TRICKERY)
    {
        if (nSpell == SPELL_INVISIBILITY) { nFinalLevel = 2; }
        else if (nSpell == SPELL_INVISIBILITY_SPHERE) { nFinalLevel = 3; }
        else if (nSpell == SPELL_IMPROVED_INVISIBILITY) { nFinalLevel = 5; }
    }
    else if (nDomain == DOMAIN_WAR)
    {
        if (nSpell == SPELL_CATS_GRACE) { nFinalLevel = 2; }
        else if (nSpell == SPELL_AURA_OF_VITALITY) { nFinalLevel = 7; }
    }
    else if (nDomain == DOMAIN_WATER)
    {
        if (nSpell == SPELL_POISON) { nFinalLevel = 2; }
        else if (nSpell == SPELL_ICE_STORM) { nFinalLevel = 5; }
    }
    return nFinalLevel;
}

int _AddToRandomSpellTempArrays(object oCreature, int nSpell, int nClass, string sClass2da, int nSpellListWeight=1, int nMetamagic=METAMAGIC_NONE, int nDomainIndex=-1)
{
    if (!_HasFeatForMetamagic(oCreature, nMetamagic))
    {
        return 0;
    }
    // multiplying by 0 results in a weight of 0, can just stop here and save VM instructions
    if (nSpellListWeight <= 0)
    {
        return 0;
    }
    // Clerics should use try to use domains in preference to not
    if (nClass == CLASS_TYPE_CLERIC && nDomainIndex == -1)
    {
        nDomainIndex = 2;
    }

    if (nClass == CLASS_TYPE_BARD || nClass == CLASS_TYPE_SORCERER)
    {
        // Spont casters don't do metamagic like this
        if (nMetamagic != METAMAGIC_NONE) { return 0; }
        // Don't give spont casters multiple copies of the same thing
        if (GetHasSpell(nSpell, oCreature)) { return 0; }
    }
    int nFinalLevel = -1;
    int nDomain = -1;
    if (nClass == CLASS_TYPE_CLERIC && nDomainIndex > 0)
    {
        nDomain = GetDomain(oCreature, nDomainIndex, CLASS_TYPE_CLERIC);
        // Look to see if this is a domain granted spell, and if you can make use of this, do
        // but some domain spells are available normally at a higher level as well, so watch out for that
        nFinalLevel = _GetLevelForSpellWithDomain(nSpell, nDomain);
    }
    if (nFinalLevel == -1)
    {
        nFinalLevel = _GetLevelForSpell(nSpell, sClass2da);
    }
    if (nFinalLevel < 0 && nClass == CLASS_TYPE_CLERIC && nDomainIndex > 0)
    {
        return _AddToRandomSpellTempArrays(oCreature, nSpell, nClass, sClass2da, nSpellListWeight, nMetamagic, nDomainIndex-1);
    }
    if (nFinalLevel < 0) { return 0; }
    nFinalLevel += _GetMetamagicLevelAdjustment(nMetamagic);
    if (Array_At_Int(RAND_SPELL_SLOTS_REMAINING, nFinalLevel) <= 0)
    {
        if (nClass == CLASS_TYPE_CLERIC && nDomainIndex > 0)
        {
            return _AddToRandomSpellTempArrays(oCreature, nSpell, nClass, sClass2da, nSpellListWeight, nMetamagic, nDomainIndex-1);
        }
        return 0;
    }
    Array_PushBack_Int(RAND_SPELL_TEMP_SPELLIDS, nSpell);
    Array_PushBack_Int(RAND_SPELL_TEMP_SPELL_LEVELS, nFinalLevel);
    Array_PushBack_Int(RAND_SPELL_TEMP_METAMAGIC, nMetamagic);
    int nRealWeight = nSpellListWeight * _GetRandomSpellWeight(oCreature, nSpell);
    Array_PushBack_Int(RAND_SPELL_TEMP_WEIGHTS, nRealWeight);
    Array_PushBack_Int(RAND_SPELL_TEMP_DOMAIN, nDomain);
    return nRealWeight;
}

json _AppendSpellDataToSpellLevelArray(json jObj, int nSpellLevel, int nSpell, int nMetamagic, int nDomain)
{
    json jSpell = JsonObject();
    jSpell = JsonObjectSet(jSpell, "id", JsonInt(nSpell));
    jSpell = JsonObjectSet(jSpell, "metamagic", JsonInt(nMetamagic));
    jSpell = JsonObjectSet(jSpell, "domain", JsonInt(nDomain));
    json jSpellArray = JsonObjectGet(jObj, IntToString(nSpellLevel));
    jSpellArray = JsonArrayInsert(jSpellArray, jSpell);
    jObj = JsonObjectSet(jObj, IntToString(nSpellLevel), jSpellArray);
    jObj = JsonObjectSet(jObj, "LastAdded", JsonInt(nSpell));
    return jObj;
}

//jObj = _AddSpellFromTempArrays(oCreature, nClass, nWeightSum, jObj);
//nAdded = JsonGetInt(JsonObjectGet(jObj, "LastAdded"));;

json _AddSpellFromTempArrays(object oCreature, int nClass, int nWeightSum, json jObj)
{
    //WriteTimestampedLogEntry("_AddSpellFromTempArrays: weightsum = " + IntToString(nWeightSum) + " arrsize=" + IntToString(Array_Size(RAND_SPELL_TEMP_SPELLIDS)));
    //Array_Debug_Dump(RAND_SPELL_TEMP_WEIGHTS, "Spell weights");
    //Array_Debug_Dump(RAND_SPELL_TEMP_SPELLIDS, "Spell ids");
    if (nWeightSum == 0 || Array_Size(RAND_SPELL_TEMP_WEIGHTS) == 0)
    {
        jObj = JsonObjectSet(jObj, "LastAdded", JsonInt(-1));
        return jObj;
    }
    int nTargetWeight = Random(nWeightSum) + 1;
    //WriteTimestampedLogEntry("Target weight = " + IntToString(nTargetWeight));
    int i = 0;
    while (1)
    {
        int nThisWeight = Array_At_Int(RAND_SPELL_TEMP_WEIGHTS, i);
        nTargetWeight -= nThisWeight;
        //WriteTimestampedLogEntry("Current pos = " + IntToString(i) + ", this weight = " + IntToString(nThisWeight) + ", target weight now " + IntToString(nTargetWeight));
        if (nTargetWeight <= 0 || i >= Array_Size(RAND_SPELL_TEMP_WEIGHTS))
        {
            // This shouldn't happen, but for sanity's sake I don't want to risk giving everything Acid Fogs
            while (i >= Array_Size(RAND_SPELL_TEMP_WEIGHTS))
            {
                i--;
            }
            int nThisSpell = Array_At_Int(RAND_SPELL_TEMP_SPELLIDS, i);
            int nThisLevel = Array_At_Int(RAND_SPELL_TEMP_SPELL_LEVELS, i);
            if (nClass == CLASS_TYPE_SORCERER || nClass == CLASS_TYPE_BARD)
            {
                WriteTimestampedLogEntry("Add spont known spell " + IntToString(nThisSpell) + " at lvl " + IntToString(nThisLevel));
                NWNX_Creature_AddKnownSpell(oCreature, nClass, nThisLevel, nThisSpell);
                jObj = _AppendSpellDataToSpellLevelArray(jObj, nThisLevel, nThisSpell, METAMAGIC_NONE, -1);
                return jObj;
            }
            else
            {
                int nThisMetamagic = Array_At_Int(RAND_SPELL_TEMP_METAMAGIC, i);
                struct NWNX_Creature_MemorisedSpell mem;
                mem.id = nThisSpell;
                mem.ready = 1;
                mem.meta = nThisMetamagic;
                int nThisDomain = Array_At_Int(RAND_SPELL_TEMP_DOMAIN, i);
                mem.domain = nThisDomain;
                int nIndex = Array_At_Int(RAND_SPELL_SLOTS_REMAINING, nThisLevel) - 1;
                Array_Set_Int(RAND_SPELL_SLOTS_REMAINING, nThisLevel, nIndex);
                //WriteTimestampedLogEntry("Add mem known spell " + IntToString(nThisSpell) + " at lvl " + IntToString(nThisLevel) + " and index " + IntToString(nIndex));
                NWNX_Creature_SetMemorisedSpell(oCreature, nClass, nThisLevel, nIndex, mem);
                jObj = _AppendSpellDataToSpellLevelArray(jObj, nThisLevel, nThisSpell, nThisMetamagic, nThisDomain);
                return jObj;
            }
        }
        i++;
    }
    jObj = JsonObjectSet(jObj, "LastAdded", JsonInt(-1));
    return jObj;
}

int _AddToRandomSpellCasterFeatArrays(object oCreature, int nFeat, int nWeight)
{
    if (GetHasFeat(nFeat, oCreature))
    {
        return 0;
    }
    if (!NWNX_Creature_GetMeetsFeatRequirements(oCreature, nFeat))
    {
        return 0;
    }
    Array_PushBack_Int(RAND_SPELL_TEMP_SPELLIDS, nFeat);
    Array_PushBack_Int(RAND_SPELL_TEMP_WEIGHTS, nWeight);
    return nWeight;
}

int _AddCasterFeatFromTempArrays(object oCreature, int nWeightSum)
{
    int nTargetWeight = Random(nWeightSum) + 1;
    int i = 0;
    while (1)
    {
        int nThisWeight = Array_At_Int(RAND_SPELL_TEMP_WEIGHTS, i);
        nTargetWeight -= nThisWeight;
        if (nTargetWeight <= 0 || i == Array_Size(RAND_SPELL_TEMP_WEIGHTS))
        {
            // This shouldn't happen, but for sanity's sake I don't want to risk giving everything Acid Fogs
            if (i == Array_Size(RAND_SPELL_TEMP_WEIGHTS))
            {
                i--;
            }
            int nThisFeat = Array_At_Int(RAND_SPELL_TEMP_SPELLIDS, i);
            NWNX_Creature_AddFeat(oCreature, nThisFeat);
            //WriteTimestampedLogEntry("Add feat " + IntToString(nThisFeat));
            return nThisFeat;
        }
        i++;
    }
    return -1;
}

void _RandomSpellbookPopulateArcane(int nSpellbookType, object oCreature, int nClass)
{
    int nOldInstructions = NWNX_Util_GetInstructionLimit();
    NWNX_Util_SetInstructionLimit(52428888);
    string sClass2da = _GetSpells2daColumnForClass(nClass);
    _ClearSpellbook(oCreature, nClass);
    
    json jObj = JsonObject();
    json jFeats = JsonArray();
    
    jObj = JsonObjectSet(jObj, "SpellbookType", JsonInt(nSpellbookType));
    jObj = JsonObjectSet(jObj, "0", JsonArray());
    jObj = JsonObjectSet(jObj, "1", JsonArray());
    jObj = JsonObjectSet(jObj, "2", JsonArray());
    jObj = JsonObjectSet(jObj, "3", JsonArray());
    jObj = JsonObjectSet(jObj, "4", JsonArray());
    jObj = JsonObjectSet(jObj, "5", JsonArray());
    jObj = JsonObjectSet(jObj, "6", JsonArray());
    jObj = JsonObjectSet(jObj, "7", JsonArray());
    jObj = JsonObjectSet(jObj, "8", JsonArray());
    jObj = JsonObjectSet(jObj, "9", JsonArray());
    // I don't care what list you're on, get something physically defensive
    int nWeightSum = 0;
    _ClearRandomSpellTempArrays();
    nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_MAGE_ARMOR, nClass, sClass2da, 4);
    nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SHIELD, nClass, sClass2da, 6);
    nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_STONESKIN, nClass, sClass2da, 40);
    nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_GREATER_STONESKIN, nClass, sClass2da, 80);
    nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_IMPROVED_INVISIBILITY, nClass, sClass2da, 40);
    nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_PREMONITION, nClass, sClass2da, 160);
    _AddSpellFromTempArrays(oCreature, nClass, nWeightSum, jObj);
    int nCasterLevel = GetLevelByClass(nClass, oCreature);
    int nLeft;
    int nAssigned;
    int bHasSummon = 0;
    int bHasDamageShield = 0;
    int bHasHaste = 0;

    int nCasterFeats = GetLocalInt(oCreature, "rand_feat_caster");
    int i;
    int nAdded;
    
    // All equal should produce a fairly mixed, but useful random spellbook with mostly offense, a good amount of defense, and a bit of other stuff
    // Some things are significantly rarer than others at a base level, eg cure conditions
    // Many utility things are also set to become significantly more common in "later" spell slots
    
    struct CategoryWeights cwWeights;
    
    // Eg magic missile, melf's acid arrow
    cwWeights.nWeightDamagingSingleTarget = 10;
    // Eg chain lightning, firebrand
    cwWeights.nWeightDamagingAoESelective = 10;
    // Eg fireball, lightning bolt
    cwWeights.nWeightDamagingAoENonSelective = 10;
    // Eg charm person, blindness/deafness
    cwWeights.nWeightControlSingleTarget = 10;
    // Eg slow, mass blind/deaf
    cwWeights.nWeightControlAoESelective = 10;
    // Eg confusion
    cwWeights.nWeightControlAoENonSelective = 10;
    // Eg haste, boost to casting ability modifier, dispel, spell breaches
    cwWeights.nWeightOffensiveUtility = 10;
    // Eg remove blindness/deafness
    cwWeights.nWeightCureConditions = 10;
    // Eg shield, mage armor, spell mantles
    cwWeights.nWeightDefences = 10;
    cwWeights.nWeightMeleeAbility = 0;
    
    
    
    int nWeightSpellFocusAbjuration = 0;
    int nWeightSpellFocusConjuration = 0;
    int nWeightSpellFocusDivination = 0;
    int nWeightSpellFocusEnchantment = 0;
    int nWeightSpellFocusEvocation = 0;
    int nWeightSpellFocusIllusion = 0;
    int nWeightSpellFocusNecromancy = 0;
    int nWeightSpellFocusTransmutation = 0;
    int nWeightSpellPenetration = 10;
    int nWeightExtendSpell = 0;
    int nWeightEmpowerSpell = 0;
    int nWeightMaximizeSpell = 0;
    

    if (nSpellbookType == RAND_SPELL_ARCANE_EVOKER_SINGLE_TARGET)
    {
        cwWeights.nWeightDamagingSingleTarget = 5;
        cwWeights.nWeightDamagingAoESelective = 4;
        cwWeights.nWeightDamagingAoENonSelective = 1;
        cwWeights.nWeightControlSingleTarget = 2;
        cwWeights.nWeightControlAoESelective = 2;
        cwWeights.nWeightControlAoENonSelective = 1;
        cwWeights.nWeightOffensiveUtility = 5;
        cwWeights.nWeightCureConditions = 2;
        cwWeights.nWeightDefences = 3;
        
        nWeightSpellPenetration = 80;
        nWeightSpellFocusEvocation = 10;
        if (nCasterLevel >= 5) { nWeightSpellFocusEvocation = 50; }
        // For finger of death and wail of the banshee
        if (nCasterLevel >= 13) { nWeightSpellFocusNecromancy = 15; }
        // For flesh to stone
        if (nCasterLevel >= 11) { nWeightSpellFocusTransmutation = 10; }
        // Phantasmal killer and weird
         if (nCasterLevel >= 7) { nWeightSpellFocusIllusion = 15; }
        nWeightExtendSpell = 10;
        nWeightMaximizeSpell = max(0, 7 * (nCasterLevel - 7));
        nWeightEmpowerSpell = max(0, 6 * (nCasterLevel - 5));
    }
    else if (nSpellbookType == RAND_SPELL_ARCANE_EVOKER_AOE)
    {
        cwWeights.nWeightDamagingSingleTarget = 3;
        cwWeights.nWeightDamagingAoESelective = 5;
        cwWeights.nWeightDamagingAoENonSelective = 5;
        cwWeights.nWeightControlSingleTarget = 1;
        cwWeights.nWeightControlAoESelective = 3;
        cwWeights.nWeightControlAoENonSelective = 3;
        cwWeights.nWeightOffensiveUtility = 5;
        cwWeights.nWeightCureConditions = 2;
        cwWeights.nWeightDefences = 3;
        
        nWeightSpellPenetration = 80;
        nWeightSpellFocusEvocation = 10;
        if (nCasterLevel >= 5) { nWeightSpellFocusEvocation = 50; }
        // For horrid wilting and wail of the banshee
        if (nCasterLevel >= 16) { nWeightSpellFocusNecromancy = 40; }
        // Phantasmal killer and weird
        if (nCasterLevel >= 7) { nWeightSpellFocusIllusion = 15; }
        nWeightExtendSpell = 10;
        nWeightMaximizeSpell = max(0, 7 * (nCasterLevel - 7));
        nWeightEmpowerSpell = max(0, 6 * (nCasterLevel - 5));
    }
    else if (nSpellbookType == RAND_SPELL_ARCANE_SINGLE_TARGET_BALANCED)
    {
        cwWeights.nWeightDamagingSingleTarget = 4;
        cwWeights.nWeightDamagingAoESelective = 4;
        cwWeights.nWeightDamagingAoENonSelective = 1;
        cwWeights.nWeightControlSingleTarget = 4;
        cwWeights.nWeightControlAoESelective = 4;
        cwWeights.nWeightControlAoENonSelective = 1;
        cwWeights.nWeightOffensiveUtility = 4;
        cwWeights.nWeightCureConditions = 1;
        cwWeights.nWeightDefences = 3;
        
        nWeightSpellPenetration = 80;
        nWeightSpellFocusEvocation = 10;
        if (nCasterLevel >= 5) { nWeightSpellFocusEvocation = 50; }
        if (nCasterLevel >= 5) { nWeightSpellFocusEnchantment = 50; }
        if (nCasterLevel >= 5) { nWeightSpellFocusConjuration = 30; }
        // For horrid wilting and wail of the banshee
        if (nCasterLevel >= 16) { nWeightSpellFocusNecromancy = 40; }
        // Phantasmal killer and weird
        if (nCasterLevel >= 7) { nWeightSpellFocusIllusion = 15; }
        nWeightExtendSpell = 10;
        nWeightMaximizeSpell = max(0, 7 * (nCasterLevel - 7));
        nWeightEmpowerSpell = max(0, 6 * (nCasterLevel - 5));
    }
    else if (nSpellbookType == RAND_SPELL_ARCANE_CONTROLLER)
    {
        cwWeights.nWeightDamagingSingleTarget = 2;
        cwWeights.nWeightDamagingAoESelective = 1;
        cwWeights.nWeightDamagingAoENonSelective = 1;
        cwWeights.nWeightControlSingleTarget = 5;
        cwWeights.nWeightControlAoESelective = 5;
        cwWeights.nWeightControlAoENonSelective = 4;
        cwWeights.nWeightOffensiveUtility = 4;
        cwWeights.nWeightCureConditions = 1;
        cwWeights.nWeightDefences = 3;
        
        nWeightSpellPenetration = 80;
        if (nCasterLevel >= 5) { nWeightSpellFocusEnchantment = 50; }
        // Phantasmal killer and weird
        if (nCasterLevel >= 7) { nWeightSpellFocusIllusion = 30; }
        nWeightExtendSpell = 10;
        nWeightMaximizeSpell = max(0, 7 * (nCasterLevel - 7));
        nWeightEmpowerSpell = max(0, 6 * (nCasterLevel - 5));
    }
    else if (nSpellbookType == RAND_SPELL_ARCANE_BARD)
    {
        cwWeights.nWeightDamagingSingleTarget = 1;
        cwWeights.nWeightDamagingAoESelective = 1;
        cwWeights.nWeightDamagingAoENonSelective = 1;
        cwWeights.nWeightControlSingleTarget = 3;
        cwWeights.nWeightControlAoESelective = 3;
        cwWeights.nWeightControlAoENonSelective = 3;
        cwWeights.nWeightOffensiveUtility = 5;
        cwWeights.nWeightCureConditions = 3;
        cwWeights.nWeightDefences = 5;
        cwWeights.nWeightMeleeAbility = 5;
        
        nWeightSpellPenetration = 20;
        if (nCasterLevel >= 5) { nWeightSpellFocusEnchantment = 40; }
        nWeightExtendSpell = 40;
    }
    
    
    
         
    if (nCasterFeats > 0)
    {
        for (i=0; i<nCasterFeats; i++)
        {
            nWeightSum = 0;
            _ClearRandomSpellTempArrays();
            nWeightSum += _AddToRandomSpellCasterFeatArrays(oCreature, FEAT_EXTEND_SPELL, nWeightExtendSpell);
            nWeightSum += _AddToRandomSpellCasterFeatArrays(oCreature, FEAT_MAXIMIZE_SPELL, nWeightMaximizeSpell);
            nWeightSum += _AddToRandomSpellCasterFeatArrays(oCreature, FEAT_EMPOWER_SPELL, nWeightEmpowerSpell);
            nWeightSum += _AddToRandomSpellCasterFeatArrays(oCreature, FEAT_SPELL_PENETRATION, nWeightSpellPenetration);
            if (GetHasFeat(FEAT_SPELL_PENETRATION))
            {
                nWeightSum += _AddToRandomSpellCasterFeatArrays(oCreature, FEAT_GREATER_SPELL_PENETRATION, nWeightSpellPenetration);
            }
            nWeightSum += _AddToRandomSpellCasterFeatArrays(oCreature, FEAT_SPELL_FOCUS_ABJURATION, nWeightSpellFocusAbjuration);
            if (GetHasFeat(FEAT_SPELL_FOCUS_ABJURATION, oCreature))
            {
                nWeightSum += _AddToRandomSpellCasterFeatArrays(oCreature, FEAT_GREATER_SPELL_FOCUS_ABJURATION, nWeightSpellFocusAbjuration);
            }
            nWeightSum += _AddToRandomSpellCasterFeatArrays(oCreature, FEAT_SPELL_FOCUS_CONJURATION, nWeightSpellFocusConjuration);
            if (GetHasFeat(FEAT_SPELL_FOCUS_CONJURATION, oCreature))
            {
                nWeightSum += _AddToRandomSpellCasterFeatArrays(oCreature, FEAT_GREATER_SPELL_FOCUS_CONJURATION, nWeightSpellFocusConjuration);
            }
            nWeightSum += _AddToRandomSpellCasterFeatArrays(oCreature, FEAT_SPELL_FOCUS_DIVINATION, nWeightSpellFocusDivination);
            if (GetHasFeat(FEAT_SPELL_FOCUS_DIVINATION, oCreature))
            {
                nWeightSum += _AddToRandomSpellCasterFeatArrays(oCreature, FEAT_GREATER_SPELL_FOCUS_DIVINATION, nWeightSpellFocusDivination);
            }
            nWeightSum += _AddToRandomSpellCasterFeatArrays(oCreature, FEAT_SPELL_FOCUS_ENCHANTMENT, nWeightSpellFocusEnchantment);
            if (GetHasFeat(FEAT_SPELL_FOCUS_ENCHANTMENT, oCreature))
            {
                nWeightSum += _AddToRandomSpellCasterFeatArrays(oCreature, FEAT_GREATER_SPELL_FOCUS_ENCHANTMENT, nWeightSpellFocusEnchantment);
            }
            nWeightSum += _AddToRandomSpellCasterFeatArrays(oCreature, FEAT_SPELL_FOCUS_EVOCATION, nWeightSpellFocusEvocation);
            if (GetHasFeat(FEAT_SPELL_FOCUS_EVOCATION, oCreature))
            {
                nWeightSum += _AddToRandomSpellCasterFeatArrays(oCreature, FEAT_GREATER_SPELL_FOCUS_EVOCATION, nWeightSpellFocusEvocation);
            }
            nWeightSum += _AddToRandomSpellCasterFeatArrays(oCreature, FEAT_SPELL_FOCUS_ILLUSION, nWeightSpellFocusIllusion);
            if (GetHasFeat(FEAT_SPELL_FOCUS_ILLUSION, oCreature))
            {
                nWeightSum += _AddToRandomSpellCasterFeatArrays(oCreature, FEAT_GREATER_SPELL_FOCUS_ILLUSION, nWeightSpellFocusIllusion);
            }
            nWeightSum += _AddToRandomSpellCasterFeatArrays(oCreature, FEAT_SPELL_FOCUS_NECROMANCY, nWeightSpellFocusNecromancy);
            if (GetHasFeat(FEAT_SPELL_FOCUS_NECROMANCY, oCreature))
            {
                nWeightSum += _AddToRandomSpellCasterFeatArrays(oCreature, FEAT_GREATER_SPELL_FOCUS_NECROMANCY, nWeightSpellFocusNecromancy);
            }
            nWeightSum += _AddToRandomSpellCasterFeatArrays(oCreature, FEAT_SPELL_FOCUS_TRANSMUTATION, nWeightSpellFocusTransmutation);
            if (GetHasFeat(FEAT_SPELL_FOCUS_TRANSMUTATION, oCreature))
            {
                nWeightSum += _AddToRandomSpellCasterFeatArrays(oCreature, FEAT_GREATER_SPELL_FOCUS_TRANSMUTATION, nWeightSpellFocusTransmutation);
            }
            nWeightSum += _AddToRandomSpellCasterFeatArrays(oCreature, FEAT_ARCANE_DEFENSE_ABJURATION, nWeightSpellFocusAbjuration/4);
            nWeightSum += _AddToRandomSpellCasterFeatArrays(oCreature, FEAT_ARCANE_DEFENSE_CONJURATION, nWeightSpellFocusConjuration/4);
            nWeightSum += _AddToRandomSpellCasterFeatArrays(oCreature, FEAT_ARCANE_DEFENSE_DIVINATION, nWeightSpellFocusDivination/4);
            nWeightSum += _AddToRandomSpellCasterFeatArrays(oCreature, FEAT_ARCANE_DEFENSE_ENCHANTMENT, nWeightSpellFocusEnchantment/4);
            nWeightSum += _AddToRandomSpellCasterFeatArrays(oCreature, FEAT_ARCANE_DEFENSE_EVOCATION, nWeightSpellFocusEvocation/4);
            nWeightSum += _AddToRandomSpellCasterFeatArrays(oCreature, FEAT_ARCANE_DEFENSE_ILLUSION, nWeightSpellFocusIllusion/4);
            nWeightSum += _AddToRandomSpellCasterFeatArrays(oCreature, FEAT_ARCANE_DEFENSE_NECROMANCY, nWeightSpellFocusNecromancy/4);
            nWeightSum += _AddToRandomSpellCasterFeatArrays(oCreature, FEAT_ARCANE_DEFENSE_TRANSMUTATION, nWeightSpellFocusTransmutation/4);
            if (nWeightSum == 0) { break; }
            int nFeat = _AddCasterFeatFromTempArrays(oCreature, nWeightSum);
            jFeats = JsonArrayInsert(jFeats, JsonInt(nFeat));
        }
    }
    
    // This will also take into account spell focus feats that are fixed on the UTC itself, as well any that got added
    int nSpellFocusAbjuration = GetHasFeat(FEAT_SPELL_FOCUS_ABJURATION, oCreature) + GetHasFeat(FEAT_GREATER_SPELL_FOCUS_ABJURATION, oCreature);
    int nSpellFocusConjuration = GetHasFeat(FEAT_SPELL_FOCUS_CONJURATION, oCreature) + GetHasFeat(FEAT_GREATER_SPELL_FOCUS_CONJURATION, oCreature);
    int nSpellFocusDivination = GetHasFeat(FEAT_SPELL_FOCUS_DIVINATION, oCreature) + GetHasFeat(FEAT_GREATER_SPELL_FOCUS_DIVINATION, oCreature);
    int nSpellFocusEnchantment = GetHasFeat(FEAT_SPELL_FOCUS_ENCHANTMENT, oCreature) + GetHasFeat(FEAT_GREATER_SPELL_FOCUS_ENCHANTMENT, oCreature);
    int nSpellFocusEvocation = GetHasFeat(FEAT_SPELL_FOCUS_EVOCATION, oCreature) + GetHasFeat(FEAT_GREATER_SPELL_FOCUS_EVOCATION, oCreature);
    int nSpellFocusIllusion = GetHasFeat(FEAT_SPELL_FOCUS_ILLUSION, oCreature) + GetHasFeat(FEAT_GREATER_SPELL_FOCUS_ILLUSION, oCreature);
    int nSpellFocusTransmutation = GetHasFeat(FEAT_SPELL_FOCUS_TRANSMUTATION, oCreature) + GetHasFeat(FEAT_GREATER_SPELL_FOCUS_TRANSMUTATION, oCreature);
    int nSpellFocusNecromancy = GetHasFeat(FEAT_SPELL_FOCUS_NECROMANCY, oCreature) + GetHasFeat(FEAT_GREATER_SPELL_FOCUS_NECROMANCY, oCreature);
    
    
    // This is an abomination but also I can't think of a better way to do this
    cwWeights.nHighestCategoryWeight = max(max(max(max(max(max(max(max(max(cwWeights.nWeightDamagingSingleTarget, cwWeights.nWeightDamagingAoESelective), cwWeights.nWeightDamagingAoENonSelective), cwWeights.nWeightControlSingleTarget), cwWeights.nWeightControlAoESelective), cwWeights.nWeightControlAoENonSelective), cwWeights.nWeightOffensiveUtility), cwWeights.nWeightCureConditions), cwWeights.nWeightDefences), cwWeights.nWeightMeleeAbility);
    
    struct CategoryWeights cwThisAssignment;
    
    if (nClass != CLASS_TYPE_BARD)
    {
        nAssigned = 0;
        nLeft = Array_At_Int(RAND_SPELL_SLOTS_REMAINING, 9);
        
        
        while (nLeft > 0)
        {
            cwThisAssignment = _CalculateWeightForSpellAssignment(cwWeights, nAssigned);
            nWeightSum = 0;
            _ClearRandomSpellTempArrays();
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_ISAACS_GREATER_MISSILE_STORM, nClass, sClass2da, 30 * cwThisAssignment.nWeightDamagingSingleTarget, METAMAGIC_MAXIMIZE);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_BIGBYS_CRUSHING_HAND, nClass, sClass2da, 15 * (cwThisAssignment.nWeightControlSingleTarget + cwThisAssignment.nWeightDamagingSingleTarget));
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_BIGBYS_CLENCHED_FIST, nClass, sClass2da, (12 + nSpellFocusEvocation * 4) * (cwThisAssignment.nWeightControlSingleTarget + cwThisAssignment.nWeightDamagingSingleTarget), METAMAGIC_EXTEND);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_MORDENKAINENS_DISJUNCTION, nClass, sClass2da, (2 - GetHasSpell(SPELL_MORDENKAINENS_DISJUNCTION, oCreature)) * 15 * cwThisAssignment.nWeightOffensiveUtility);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_ENERGY_DRAIN, nClass, sClass2da, (26 + nSpellFocusNecromancy * 8) * cwThisAssignment.nWeightControlSingleTarget);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_WAIL_OF_THE_BANSHEE, nClass, sClass2da, (26 + nSpellFocusNecromancy * 8) * cwThisAssignment.nWeightDamagingAoESelective);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_WEIRD, nClass, sClass2da, (26 + nSpellFocusIllusion * 8) * cwThisAssignment.nWeightDamagingAoESelective);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_CHAIN_LIGHTNING, nClass, sClass2da, (26 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightDamagingAoESelective, METAMAGIC_MAXIMIZE);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_POWER_WORD_KILL, nClass, sClass2da, 15 * cwThisAssignment.nWeightDamagingSingleTarget);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_TIME_STOP, nClass, sClass2da, (2 - GetHasSpell(SPELL_TIME_STOP, oCreature)) * 15 * cwThisAssignment.nWeightOffensiveUtility);
            if (!GetHasSpell(SPELL_ACID_FOG, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_ACID_FOG, nClass, sClass2da,(18 + nSpellFocusConjuration * 8) * cwThisAssignment.nWeightDamagingAoENonSelective, METAMAGIC_MAXIMIZE);
            }
            // Empowered spell mantle is just better than the level 9 version, if you can cast it...
            if (GetHasFeat(FEAT_EMPOWER_SPELL, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SPELL_MANTLE, nClass, sClass2da, (2 - GetHasSpell(SPELL_SPELL_MANTLE, oCreature)) * 10 * cwThisAssignment.nWeightDefences, METAMAGIC_EMPOWER);
            }
            else
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_GREATER_SPELL_MANTLE, nClass, sClass2da, (2 - GetHasSpell(SPELL_GREATER_SPELL_MANTLE, oCreature)) * 10 * cwThisAssignment.nWeightDefences);
            }
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_MASS_CHARM, nClass, sClass2da, (26 + nSpellFocusEnchantment * 8) * cwThisAssignment.nWeightControlAoESelective);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_MASS_BLINDNESS_AND_DEAFNESS, nClass, sClass2da, (26 + nSpellFocusIllusion * 8) * cwThisAssignment.nWeightControlAoESelective);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_DOMINATE_MONSTER, nClass, sClass2da, (26 + nSpellFocusEnchantment * 8) * cwThisAssignment.nWeightControlSingleTarget);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_METEOR_SWARM, nClass, sClass2da, (26 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightDamagingAoENonSelective);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_DELAYED_BLAST_FIREBALL, nClass, sClass2da, (26 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightDamagingAoENonSelective, METAMAGIC_EMPOWER);
            if (!bHasSummon)
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SUMMON_CREATURE_IX, nClass, sClass2da, 40 * cwThisAssignment.nHighestCategoryWeight);
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_GATE, nClass, sClass2da, 40 * cwThisAssignment.nHighestCategoryWeight);
            }
            jObj = _AddSpellFromTempArrays(oCreature, nClass, nWeightSum, jObj);
            nAdded = JsonGetInt(JsonObjectGet(jObj, "LastAdded"));
            if (nAdded == SPELL_SUMMON_CREATURE_IX || nAdded == SPELL_GATE)
            {
                bHasSummon = 1;
            }
            nAssigned++;
            nLeft--;
        }

        nLeft = Array_At_Int(RAND_SPELL_SLOTS_REMAINING, 8);
        nAssigned = 0;
        while (nLeft > 0)
        {
            cwThisAssignment = _CalculateWeightForSpellAssignment(cwWeights, nAssigned);
             nWeightSum = 0;
            _ClearRandomSpellTempArrays();
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_BIGBYS_CLENCHED_FIST, nClass, sClass2da, (12 + nSpellFocusEvocation * 4) * (cwThisAssignment.nWeightControlSingleTarget + cwThisAssignment.nWeightDamagingSingleTarget));
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_FIREBRAND, nClass, sClass2da, (18 + nSpellFocusEvocation * 4) * (cwThisAssignment.nWeightDamagingAoESelective + cwThisAssignment.nWeightDamagingSingleTarget), METAMAGIC_MAXIMIZE);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_BALL_LIGHTNING, nClass, sClass2da, (28 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightDamagingSingleTarget, METAMAGIC_MAXIMIZE);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_CONE_OF_COLD, nClass, sClass2da,(28 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightDamagingAoENonSelective, METAMAGIC_MAXIMIZE);
            if (!GetHasSpell(SPELL_ACID_FOG, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_ACID_FOG, nClass, sClass2da,(18 + nSpellFocusConjuration * 8) * cwThisAssignment.nWeightDamagingAoENonSelective, METAMAGIC_EMPOWER);
            }
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_FEEBLEMIND, nClass, sClass2da, (10 + nSpellFocusDivination * 8) * cwThisAssignment.nWeightControlSingleTarget, METAMAGIC_MAXIMIZE);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_CHAIN_LIGHTNING, nClass, sClass2da, (8 + nSpellFocusEvocation * 4) * (cwThisAssignment.nWeightDamagingAoESelective + cwThisAssignment.nWeightDamagingSingleTarget), METAMAGIC_EMPOWER);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_ISAACS_GREATER_MISSILE_STORM, nClass, sClass2da, 30 * cwThisAssignment.nWeightDamagingSingleTarget, METAMAGIC_EMPOWER);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_HORRID_WILTING, nClass, sClass2da, (30 + nSpellFocusNecromancy * 8) * cwThisAssignment.nWeightDamagingAoENonSelective);
            if (!GetHasSpell(SPELL_INCENDIARY_CLOUD, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_INCENDIARY_CLOUD, nClass, sClass2da, (20 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightDamagingAoENonSelective);
            }
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_MASS_BLINDNESS_AND_DEAFNESS, nClass, sClass2da, (26 + nSpellFocusIllusion * 8) * cwThisAssignment.nWeightControlAoESelective);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_MASS_CHARM, nClass, sClass2da, (26 + nSpellFocusEnchantment * 8) * cwThisAssignment.nWeightControlAoESelective);
            if (!GetHasSpell(SPELL_MIND_BLANK, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_MIND_BLANK, nClass, sClass2da, 25 * cwThisAssignment.nWeightDefences);
            }
            if (!GetHasSpell(SPELL_PREMONITION, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_PREMONITION, nClass, sClass2da, 100 * cwThisAssignment.nWeightDefences);
            }
            else
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_PREMONITION, nClass, sClass2da, 10 * cwThisAssignment.nWeightDefences);
            }
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SUNBURST, nClass, sClass2da, (15 + nSpellFocusEvocation * 4) * cwThisAssignment.nWeightDamagingAoESelective);
            if (!bHasSummon)
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SUMMON_CREATURE_VIII, nClass, sClass2da, 40 * cwThisAssignment.nHighestCategoryWeight);
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_CREATE_UNDEAD, nClass, sClass2da, 40 * cwThisAssignment.nHighestCategoryWeight);
            }
            jObj = _AddSpellFromTempArrays(oCreature, nClass, nWeightSum, jObj);
            nAdded = JsonGetInt(JsonObjectGet(jObj, "LastAdded"));
            if (nAdded == SPELL_SUMMON_CREATURE_VIII || nAdded == SPELL_CREATE_UNDEAD)
            {
                bHasSummon = 1;
            }
            nAssigned++;
            nLeft--;
        }

        nLeft = Array_At_Int(RAND_SPELL_SLOTS_REMAINING, 7);
        nAssigned = 0;
        while (nLeft > 0)
        {
            cwThisAssignment = _CalculateWeightForSpellAssignment(cwWeights, nAssigned);
            nWeightSum = 0;
           _ClearRandomSpellTempArrays();
           nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_BIGBYS_GRASPING_HAND, nClass, sClass2da, (26 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightControlSingleTarget);
           nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_CONTROL_UNDEAD, nClass, sClass2da, (10 + nSpellFocusNecromancy * 8) * cwThisAssignment.nWeightControlSingleTarget);
           nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_DELAYED_BLAST_FIREBALL, nClass, sClass2da, (26 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightDamagingAoENonSelective);
           nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_GREAT_THUNDERCLAP, nClass, sClass2da, (20 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightControlAoENonSelective);
           nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_POWER_WORD_STUN, nClass, sClass2da, 20 * cwThisAssignment.nWeightControlSingleTarget);
           nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_PRISMATIC_SPRAY, nClass, sClass2da, (26 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightDamagingAoENonSelective);
           if (!GetHasSpell(SPELL_PROTECTION_FROM_SPELLS, oCreature))
           {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_PROTECTION_FROM_SPELLS, nClass, sClass2da, 30 * cwThisAssignment.nWeightDefences);
           }
           if (!GetHasSpell(SPELL_SHADOW_SHIELD, oCreature))
           {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SHADOW_SHIELD, nClass, sClass2da, 30 * cwThisAssignment.nWeightDefences);
           }
           if (!GetHasSpell(SPELL_GREATER_SPELL_MANTLE) && !GetHasSpell(SPELL_SPELL_MANTLE) && !GetHasSpell(SPELL_LESSER_SPELL_MANTLE))
           {
               if (GetHasFeat(FEAT_EMPOWER_SPELL, oCreature))
               {
                    nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_LESSER_SPELL_MANTLE, nClass, sClass2da, 20 * cwThisAssignment.nWeightDefences, METAMAGIC_EMPOWER);
               }
               else
               {
                    nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SPELL_MANTLE, nClass, sClass2da, 20 * cwThisAssignment.nWeightDefences);
               }
           }
           
           nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_FINGER_OF_DEATH, nClass, sClass2da, (26 + nSpellFocusNecromancy * 8) * cwThisAssignment.nWeightDamagingSingleTarget);
           nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_FIREBRAND, nClass, sClass2da, (18 + nSpellFocusEvocation * 4) * (cwThisAssignment.nWeightDamagingAoESelective + cwThisAssignment.nWeightDamagingSingleTarget), METAMAGIC_EMPOWER);
           nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_BALL_LIGHTNING, nClass, sClass2da, (28 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightDamagingSingleTarget, METAMAGIC_EMPOWER);
           nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_CONE_OF_COLD, nClass, sClass2da, (28 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightDamagingAoENonSelective, METAMAGIC_EMPOWER);
           nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_FEEBLEMIND, nClass, sClass2da, (10 + nSpellFocusDivination * 8) * cwThisAssignment.nWeightControlSingleTarget, METAMAGIC_EMPOWER);
           nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_ISAACS_LESSER_MISSILE_STORM, nClass, sClass2da, 30 * cwThisAssignment.nWeightDamagingSingleTarget, METAMAGIC_MAXIMIZE);
           nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_ENERVATION, nClass, sClass2da, (26 + nSpellFocusNecromancy * 8) * cwThisAssignment.nWeightControlSingleTarget, METAMAGIC_MAXIMIZE);
           nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_ICE_STORM, nClass, sClass2da, (20 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightDamagingAoENonSelective, METAMAGIC_MAXIMIZE);
           nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_BIGBYS_FORCEFUL_HAND, nClass, sClass2da, 35 * cwThisAssignment.nWeightControlSingleTarget, METAMAGIC_EXTEND);
           if (!GetHasSpell(SPELL_EVARDS_BLACK_TENTACLES, oCreature))
           {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_EVARDS_BLACK_TENTACLES, nClass, sClass2da, (15 + nSpellFocusConjuration * 4) * (cwThisAssignment.nWeightDamagingAoENonSelective + cwThisAssignment.nWeightControlAoENonSelective), METAMAGIC_MAXIMIZE);
           }
           if (!GetHasSpell(SPELL_ETHEREAL_VISAGE, oCreature))
           {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_ETHEREAL_VISAGE, nClass, sClass2da, 50 * cwThisAssignment.nWeightDefences, METAMAGIC_EXTEND);
           }
           if (!GetHasSpell(SPELL_GLOBE_OF_INVULNERABILITY, oCreature))
           {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_GLOBE_OF_INVULNERABILITY, nClass, sClass2da, 20 * cwThisAssignment.nWeightDefences, METAMAGIC_EXTEND);
           }
           if (!GetHasSpell(SPELL_MASS_HASTE, oCreature))
           {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_MASS_HASTE, nClass, sClass2da, 100 * cwThisAssignment.nWeightOffensiveUtility, METAMAGIC_EXTEND);
           }
           if (!GetHasSpell(SPELL_WALL_OF_FIRE, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_WALL_OF_FIRE, nClass, sClass2da, (10 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightDamagingAoENonSelective, METAMAGIC_MAXIMIZE);
            }
           if (!bHasSummon)
           {
               nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SUMMON_CREATURE_VII, nClass, sClass2da, 40 * cwThisAssignment.nHighestCategoryWeight);
               nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_MORDENKAINENS_SWORD, nClass, sClass2da, 40 * cwThisAssignment.nHighestCategoryWeight);
           }
           jObj = _AddSpellFromTempArrays(oCreature, nClass, nWeightSum, jObj);
           nAdded = JsonGetInt(JsonObjectGet(jObj, "LastAdded"));
           if (nAdded == SPELL_SUMMON_CREATURE_VII || nAdded == SPELL_MORDENKAINENS_SWORD)
           {
               bHasSummon = 1;
           }
           if (nAdded == SPELL_MASS_HASTE)
           {
               bHasHaste = 1;
           }
           nAssigned++;
           nLeft--;
        }

        nLeft = Array_At_Int(RAND_SPELL_SLOTS_REMAINING, 6);
        nAssigned = 0;
        while (nLeft > 0)
        {
            cwThisAssignment = _CalculateWeightForSpellAssignment(cwWeights, nAssigned);
             nWeightSum = 0;
            _ClearRandomSpellTempArrays();
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_ISAACS_GREATER_MISSILE_STORM, nClass, sClass2da,  30 * cwThisAssignment.nWeightDamagingSingleTarget);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_CHAIN_LIGHTNING, nClass, sClass2da, (8 + nSpellFocusEvocation * 4) * (cwThisAssignment.nWeightDamagingAoESelective + cwThisAssignment.nWeightDamagingSingleTarget));
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_FLESH_TO_STONE, nClass, sClass2da,  (26 + nSpellFocusTransmutation * 8) * cwThisAssignment.nWeightDamagingSingleTarget);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_GREATER_DISPELLING, nClass, sClass2da, (2 - GetHasSpell(SPELL_GREATER_DISPELLING, oCreature)) * 15 * cwThisAssignment.nWeightOffensiveUtility);
            if (!GetHasSpell(SPELL_GREATER_SPELL_BREACH, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_GREATER_SPELL_BREACH, nClass, sClass2da, 40 * cwThisAssignment.nWeightOffensiveUtility);
            }
            if (!GetHasSpell(SPELL_ACID_FOG, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_ACID_FOG, nClass, sClass2da,(18 + nSpellFocusConjuration * 8) * cwThisAssignment.nWeightDamagingAoENonSelective);
            }
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_BIGBYS_FORCEFUL_HAND, nClass, sClass2da, 35 * cwThisAssignment.nWeightControlSingleTarget);
            if (!GetHasSpell(SPELL_CIRCLE_OF_DEATH, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_CIRCLE_OF_DEATH, nClass, sClass2da, (18 + nSpellFocusNecromancy * 8) * cwThisAssignment.nWeightDamagingAoESelective);
            }
            if (!GetHasSpell(SPELL_TRUE_SEEING, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_TRUE_SEEING, nClass, sClass2da, 10 * cwThisAssignment.nWeightOffensiveUtility);
            }
            if (!GetHasSpell(SPELL_UNDEATH_TO_DEATH, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_UNDEATH_TO_DEATH, nClass, sClass2da, (10 + nSpellFocusNecromancy * 8) * cwThisAssignment.nWeightDamagingAoESelective);
            }
            if (!GetHasSpell(SPELL_GREATER_STONESKIN, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_GREATER_STONESKIN, nClass, sClass2da, 100 * cwThisAssignment.nWeightDefences);
            }
            else
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_GREATER_STONESKIN, nClass, sClass2da, 10 * cwThisAssignment.nWeightDefences);
            }
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_ISAACS_LESSER_MISSILE_STORM, nClass, sClass2da, 30 * cwThisAssignment.nWeightDamagingSingleTarget, METAMAGIC_EMPOWER);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_ICE_STORM, nClass, sClass2da, (20 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightDamagingAoENonSelective, METAMAGIC_EMPOWER);
            if (!GetHasSpell(SPELL_WALL_OF_FIRE, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_WALL_OF_FIRE, nClass, sClass2da, (10 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightDamagingAoENonSelective, METAMAGIC_EMPOWER);
            }
            if (!GetHasSpell(SPELL_EVARDS_BLACK_TENTACLES, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_EVARDS_BLACK_TENTACLES, nClass, sClass2da, (15 + nSpellFocusConjuration * 4) * (cwThisAssignment.nWeightDamagingAoENonSelective + cwThisAssignment.nWeightControlAoENonSelective), METAMAGIC_EMPOWER);
            }
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_FLAME_ARROW, nClass, sClass2da, (nCasterLevel/4) * (14 + nSpellFocusConjuration * 2) * cwThisAssignment.nWeightDamagingSingleTarget, METAMAGIC_MAXIMIZE);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_FIREBALL, nClass, sClass2da, (10 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightDamagingAoENonSelective, METAMAGIC_MAXIMIZE);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_LIGHTNING_BOLT, nClass, sClass2da, (10 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightDamagingAoENonSelective, METAMAGIC_MAXIMIZE);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_MESTILS_ACID_BREATH, nClass, sClass2da, (10 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightDamagingAoENonSelective, METAMAGIC_MAXIMIZE);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SCINTILLATING_SPHERE, nClass, sClass2da, (10 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightDamagingAoENonSelective, METAMAGIC_MAXIMIZE);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_VAMPIRIC_TOUCH, nClass, sClass2da, 5 * cwThisAssignment.nWeightDamagingSingleTarget, METAMAGIC_MAXIMIZE);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_HOLD_MONSTER, nClass, sClass2da, (26 + nSpellFocusEnchantment * 8) * cwThisAssignment.nWeightControlSingleTarget, METAMAGIC_EXTEND);
            if (!bHasHaste)
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_MASS_HASTE, nClass, sClass2da, 100 * cwThisAssignment.nWeightOffensiveUtility);
            }
            if (!bHasSummon)
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SUMMON_CREATURE_VI, nClass, sClass2da, 40 * cwThisAssignment.nHighestCategoryWeight);
            }
            jObj = _AddSpellFromTempArrays(oCreature, nClass, nWeightSum, jObj);
            nAdded = JsonGetInt(JsonObjectGet(jObj, "LastAdded"));
            if (nAdded == SPELL_SUMMON_CREATURE_VI)
            {
                bHasSummon = 1;
            }
            if (nAdded == SPELL_MASS_HASTE)
            {
                bHasHaste = 1;
            }
            nAssigned++;
            nLeft--;
        }

        nLeft = Array_At_Int(RAND_SPELL_SLOTS_REMAINING, 5);
        nAssigned = 0;
        while (nLeft > 0)
        {
            cwThisAssignment = _CalculateWeightForSpellAssignment(cwWeights, nAssigned);
             nWeightSum = 0;
            _ClearRandomSpellTempArrays();
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_BALL_LIGHTNING, nClass, sClass2da, (28 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightDamagingSingleTarget);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_FIREBRAND, nClass, sClass2da, (18 + nSpellFocusEvocation * 4) * (cwThisAssignment.nWeightDamagingAoESelective + cwThisAssignment.nWeightDamagingSingleTarget));
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_BIGBYS_INTERPOSING_HAND, nClass, sClass2da, 30 * cwThisAssignment.nWeightControlSingleTarget);
            if (!GetHasSpell(SPELL_CLOUDKILL, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_CLOUDKILL, nClass, sClass2da, 20 * cwThisAssignment.nWeightDamagingAoENonSelective);
            }
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_CONE_OF_COLD, nClass, sClass2da, (28 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightDamagingAoENonSelective);
            if (!GetHasSpell(SPELL_DISMISSAL))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_DISMISSAL, nClass, sClass2da, (28 + nSpellFocusConjuration * 8) * cwThisAssignment.nWeightDamagingAoENonSelective);
            }
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_DOMINATE_PERSON, nClass, sClass2da, (26 + nSpellFocusEnchantment * 8) * cwThisAssignment.nWeightControlSingleTarget);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_CHARM_MONSTER, nClass, sClass2da, (26 + nSpellFocusEnchantment * 8) * cwThisAssignment.nWeightControlSingleTarget, METAMAGIC_EXTEND);
            if (!GetHasSpell(SPELL_ENERGY_BUFFER, oCreature) && !GetHasSpell(SPELL_PROTECTION_FROM_ELEMENTS, oCreature) && !GetHasSpell(SPELL_RESIST_ELEMENTS, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_ENERGY_BUFFER, nClass, sClass2da, 70 * cwThisAssignment.nWeightDefences);
            }

            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_FEEBLEMIND, nClass, sClass2da, (10 + nSpellFocusDivination * 8) * cwThisAssignment.nWeightControlSingleTarget);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_HOLD_MONSTER, nClass, sClass2da, (26 + nSpellFocusEnchantment * 8) * cwThisAssignment.nWeightControlSingleTarget);
            if (!GetHasSpell(SPELL_LESSER_SPELL_MANTLE))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_LESSER_SPELL_MANTLE, nClass, sClass2da, 30 * cwThisAssignment.nWeightDefences);
            }
            if (!GetHasSpell(SPELL_MIND_FOG, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_MIND_FOG, nClass, sClass2da, (26 + nSpellFocusEnchantment * 8)  * cwThisAssignment.nWeightControlAoENonSelective);
            }
            if (!GetHasSpell(SPELL_MIND_BLANK, oCreature) && !GetHasSpell(SPELL_LESSER_MIND_BLANK, oCreature) && !GetHasSpell(SPELL_CLARITY, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_LESSER_MIND_BLANK, nClass, sClass2da, 20 * cwThisAssignment.nWeightDefences);
            }

            if (!GetHasSpell(SPELL_MINOR_GLOBE_OF_INVULNERABILITY, oCreature) && !GetHasSpell(SPELL_GLOBE_OF_INVULNERABILITY, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_MINOR_GLOBE_OF_INVULNERABILITY, nClass, sClass2da, 20 * cwThisAssignment.nWeightDefences, METAMAGIC_EXTEND);
            }
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_FIREBALL, nClass, sClass2da, (20 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightDamagingAoENonSelective, METAMAGIC_EMPOWER);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_FLAME_ARROW, nClass, sClass2da, (nCasterLevel/4) * (14 + nSpellFocusConjuration * 2) * cwThisAssignment.nWeightDamagingSingleTarget, METAMAGIC_EMPOWER);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_MESTILS_ACID_BREATH, nClass, sClass2da, (10 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightDamagingAoENonSelective, METAMAGIC_EMPOWER);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SCINTILLATING_SPHERE, nClass, sClass2da, (10 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightDamagingAoENonSelective, METAMAGIC_EMPOWER);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_LIGHTNING_BOLT, nClass, sClass2da, (10 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightDamagingAoENonSelective, METAMAGIC_EMPOWER);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_VAMPIRIC_TOUCH, nClass, sClass2da, 5 * cwThisAssignment.nWeightDamagingSingleTarget, METAMAGIC_EMPOWER);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_GEDLEES_ELECTRIC_LOOP, nClass, sClass2da, (10 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightDamagingSingleTarget, METAMAGIC_MAXIMIZE);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_MELFS_ACID_ARROW, nClass, sClass2da, (10 + nCasterLevel) * cwThisAssignment.nWeightDamagingSingleTarget, METAMAGIC_MAXIMIZE);
            if (nClass == CLASS_TYPE_WIZARD)
            {
                if (!GetHasSpell(SPELL_FOXS_CUNNING, oCreature))
                {
                    nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_FOXS_CUNNING, nClass, sClass2da, 70 * cwThisAssignment.nWeightOffensiveUtility, METAMAGIC_MAXIMIZE);
                }
            }
            else
            {
                if (!GetHasSpell(SPELL_EAGLE_SPLEDOR, oCreature))
                {
                    nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_EAGLE_SPLEDOR, nClass, sClass2da, 70 * cwThisAssignment.nWeightOffensiveUtility, METAMAGIC_MAXIMIZE);
                }
            }

            if (!bHasSummon)
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SUMMON_CREATURE_V, nClass, sClass2da, 40 * cwThisAssignment.nHighestCategoryWeight);
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_ANIMATE_DEAD, nClass, sClass2da, 40 * cwThisAssignment.nHighestCategoryWeight);
            }
            if (!bHasDamageShield)
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_MESTILS_ACID_SHEATH, nClass, sClass2da, 60 * cwThisAssignment.nWeightDefences);
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_ELEMENTAL_SHIELD, nClass, sClass2da, 40 * cwThisAssignment.nWeightDefences, METAMAGIC_EXTEND);
            }
            jObj = _AddSpellFromTempArrays(oCreature, nClass, nWeightSum, jObj);
            nAdded = JsonGetInt(JsonObjectGet(jObj, "LastAdded"));
            if (nAdded == SPELL_SUMMON_CREATURE_V || nAdded == SPELL_ANIMATE_DEAD)
            {
                bHasSummon = 1;
            }
            if (nAdded == SPELL_MESTILS_ACID_SHEATH || nAdded == SPELL_ELEMENTAL_SHIELD)
            {
                bHasDamageShield = 1;
            }
            nAssigned++;
            nLeft--;
        }

        nLeft = Array_At_Int(RAND_SPELL_SLOTS_REMAINING, 4);
        nAssigned = 0;
        while (nLeft > 0)
        {
            cwThisAssignment = _CalculateWeightForSpellAssignment(cwWeights, nAssigned);
             nWeightSum = 0;
            _ClearRandomSpellTempArrays();
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_BESTOW_CURSE, nClass, sClass2da, (16 + nSpellFocusTransmutation * 8) * cwThisAssignment.nWeightControlSingleTarget);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_CHARM_MONSTER, nClass, sClass2da, (26 + nSpellFocusEnchantment * 8) * cwThisAssignment.nWeightControlSingleTarget);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_CONFUSION, nClass, sClass2da, (26 + nSpellFocusEnchantment * 8) * cwThisAssignment.nWeightControlAoENonSelective);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_FEAR, nClass, sClass2da, (26 + nSpellFocusNecromancy * 8) * cwThisAssignment.nWeightControlAoENonSelective);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_CONTAGION, nClass, sClass2da, (10 + nSpellFocusNecromancy * 8) * cwThisAssignment.nWeightControlSingleTarget);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_ENERVATION, nClass, sClass2da, (20 + nSpellFocusNecromancy * 8) * cwThisAssignment.nWeightControlSingleTarget);
            if (!GetHasSpell(SPELL_EVARDS_BLACK_TENTACLES, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_EVARDS_BLACK_TENTACLES, nClass, sClass2da, (15 + nSpellFocusConjuration * 4) * (cwThisAssignment.nWeightDamagingAoENonSelective + cwThisAssignment.nWeightControlAoENonSelective));
            }
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_ICE_STORM, nClass, sClass2da, (20 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightDamagingAoENonSelective);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_ISAACS_LESSER_MISSILE_STORM, nClass, sClass2da, 30 * cwThisAssignment.nWeightDamagingSingleTarget);
            if (!GetHasSpell(SPELL_LESSER_SPELL_BREACH, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_LESSER_SPELL_BREACH, nClass, sClass2da, 40 * cwThisAssignment.nWeightOffensiveUtility);
            }
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_PHANTASMAL_KILLER, nClass, sClass2da, (18 + nSpellFocusIllusion * 8) * cwThisAssignment.nWeightDamagingSingleTarget);
            if (!GetHasSpell(SPELL_REMOVE_BLINDNESS_AND_DEAFNESS, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_REMOVE_BLINDNESS_AND_DEAFNESS, nClass, sClass2da, 3 * cwThisAssignment.nWeightCureConditions);
            }
            if (!GetHasSpell(SPELL_REMOVE_CURSE, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_REMOVE_CURSE, nClass, sClass2da, 3 * cwThisAssignment.nWeightCureConditions);
            }
            if (!GetHasSpell(SPELL_WALL_OF_FIRE, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_WALL_OF_FIRE, nClass, sClass2da, (10 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightDamagingAoENonSelective);
            }
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_GEDLEES_ELECTRIC_LOOP, nClass, sClass2da, (10 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightDamagingSingleTarget, METAMAGIC_EMPOWER);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_MELFS_ACID_ARROW, nClass, sClass2da, (10 + nCasterLevel) * cwThisAssignment.nWeightDamagingSingleTarget, METAMAGIC_EMPOWER);
             if (nClass == CLASS_TYPE_WIZARD)
            {
                if (!GetHasSpell(SPELL_FOXS_CUNNING, oCreature))
                {
                    nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_FOXS_CUNNING, nClass, sClass2da, 70 * cwThisAssignment.nWeightOffensiveUtility, METAMAGIC_EMPOWER);
                }
            }
            else
            {
                if (!GetHasSpell(SPELL_EAGLE_SPLEDOR, oCreature))
                {
                    nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_EAGLE_SPLEDOR, nClass, sClass2da, 70 * cwThisAssignment.nWeightOffensiveUtility, METAMAGIC_EMPOWER);
                }
            }
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_MAGIC_MISSILE, nClass, sClass2da, (10 + nCasterLevel * 4) * cwThisAssignment.nWeightDamagingSingleTarget, METAMAGIC_MAXIMIZE);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_HORIZIKAULS_BOOM, nClass, sClass2da, (8 + nSpellFocusEvocation + nCasterLevel * 4) * cwThisAssignment.nWeightDamagingSingleTarget, METAMAGIC_MAXIMIZE);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_ICE_DAGGER, nClass, sClass2da, (18 + nCasterLevel) * cwThisAssignment.nWeightDamagingSingleTarget, METAMAGIC_MAXIMIZE);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_NEGATIVE_ENERGY_RAY, nClass, sClass2da, (8 + nSpellFocusNecromancy + nCasterLevel * 4) * cwThisAssignment.nWeightDamagingSingleTarget, METAMAGIC_MAXIMIZE);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_BURNING_HANDS, nClass, sClass2da, (8 + nSpellFocusTransmutation * 8) * cwThisAssignment.nWeightDamagingAoENonSelective, METAMAGIC_MAXIMIZE);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_HOLD_PERSON, nClass, sClass2da, (26 + nSpellFocusEnchantment * 8) * cwThisAssignment.nWeightControlSingleTarget, METAMAGIC_EXTEND);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SLOW, nClass, sClass2da, (26 + nSpellFocusTransmutation * 8) * cwThisAssignment.nWeightControlAoESelective, METAMAGIC_EXTEND);
            if (!bHasHaste)
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_HASTE, nClass, sClass2da, 60 * cwThisAssignment.nWeightOffensiveUtility, METAMAGIC_EXTEND);
            }
            if (!GetHasSpell(SPELL_IMPROVED_INVISIBILITY, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_IMPROVED_INVISIBILITY, nClass, sClass2da, 100 * cwThisAssignment.nWeightDefences);
            }

            if (!GetHasSpell(SPELL_STONESKIN, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_STONESKIN, nClass, sClass2da, 100 * cwThisAssignment.nWeightDefences);
            }
            else
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_STONESKIN, nClass, sClass2da, 10 * cwThisAssignment.nWeightDefences);
            }

            if (!GetHasSpell(SPELL_MINOR_GLOBE_OF_INVULNERABILITY, oCreature) && !GetHasSpell(SPELL_GLOBE_OF_INVULNERABILITY, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_MINOR_GLOBE_OF_INVULNERABILITY, nClass, sClass2da, 20 * cwThisAssignment.nWeightDefences);
            }

            if (!bHasSummon)
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SUMMON_CREATURE_IV, nClass, sClass2da, 40 * cwThisAssignment.nHighestCategoryWeight);
            }
            if (!bHasDamageShield)
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_ELEMENTAL_SHIELD, nClass, sClass2da, 50 * cwThisAssignment.nWeightDefences);
            }
            jObj = _AddSpellFromTempArrays(oCreature, nClass, nWeightSum, jObj);
            nAdded = JsonGetInt(JsonObjectGet(jObj, "LastAdded"));
            if (nAdded == SPELL_SUMMON_CREATURE_IV || nAdded == SPELL_ANIMATE_DEAD)
            {
                bHasSummon = 1;
            }
            if (nAdded == SPELL_MESTILS_ACID_SHEATH || nAdded == SPELL_ELEMENTAL_SHIELD)
            {
                bHasDamageShield = 1;
            }
            if (nAdded == SPELL_HASTE)
            {
                bHasHaste = 1;
            }
            nAssigned++;
            nLeft--;
        }

        nLeft = Array_At_Int(RAND_SPELL_SLOTS_REMAINING, 3);
        nAssigned = 0;
        while (nLeft > 0)
        {
            cwThisAssignment = _CalculateWeightForSpellAssignment(cwWeights, nAssigned);
             nWeightSum = 0;
            _ClearRandomSpellTempArrays();
            if (!GetHasSpell(SPELL_CLAIRAUDIENCE_AND_CLAIRVOYANCE, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_CLAIRAUDIENCE_AND_CLAIRVOYANCE, nClass, sClass2da, 5 * cwThisAssignment.nWeightOffensiveUtility);
            }
            if (!GetHasSpell(SPELL_CLARITY, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_CLARITY, nClass, sClass2da, 5 * cwThisAssignment.nWeightDefences);
            }
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_DISPEL_MAGIC, nClass, sClass2da,  (2 - GetHasSpell(SPELL_DISPEL_MAGIC, oCreature)) * 15 * cwThisAssignment.nWeightOffensiveUtility);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_FIREBALL, nClass, sClass2da, (20 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightDamagingAoENonSelective);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_FLAME_ARROW, nClass, sClass2da, (nCasterLevel/4) * (14 + nSpellFocusConjuration * 2) * cwThisAssignment.nWeightDamagingSingleTarget);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_GUST_OF_WIND, nClass, sClass2da, (20 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightControlAoENonSelective);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_HOLD_PERSON, nClass, sClass2da, (26 + nSpellFocusEnchantment * 8) * cwThisAssignment.nWeightControlSingleTarget);
            if (!GetHasSpell(SPELL_INVISIBILITY_SPHERE, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_INVISIBILITY_SPHERE, nClass, sClass2da, 5 * cwThisAssignment.nWeightDefences);
            }
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_LIGHTNING_BOLT, nClass, sClass2da, (10 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightDamagingAoENonSelective);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_MESTILS_ACID_BREATH, nClass, sClass2da, (10 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightDamagingAoENonSelective);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SCINTILLATING_SPHERE, nClass, sClass2da, (10 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightDamagingAoENonSelective);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_NEGATIVE_ENERGY_BURST, nClass, sClass2da, (10 + nSpellFocusNecromancy * 8) * cwThisAssignment.nWeightDamagingAoENonSelective);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SLOW, nClass, sClass2da, (26 + nSpellFocusTransmutation * 8) * cwThisAssignment.nWeightControlAoESelective);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_STINKING_CLOUD, nClass, sClass2da, (26 + nSpellFocusConjuration * 8) * cwThisAssignment.nWeightControlAoENonSelective);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_VAMPIRIC_TOUCH, nClass, sClass2da, 10 * cwThisAssignment.nWeightDamagingSingleTarget);
            if (GetAlignmentGoodEvil(oCreature) != ALIGNMENT_GOOD)
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_MAGIC_CIRCLE_AGAINST_GOOD, nClass, sClass2da, 5 * cwThisAssignment.nWeightDefences);
            }
            if (GetAlignmentGoodEvil(oCreature) != ALIGNMENT_EVIL)
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_MAGIC_CIRCLE_AGAINST_EVIL, nClass, sClass2da, 5 * cwThisAssignment.nWeightDefences);
            }
            if (!GetHasSpell(SPELL_ENERGY_BUFFER, oCreature) && !GetHasSpell(SPELL_PROTECTION_FROM_ELEMENTS, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_PROTECTION_FROM_ELEMENTS, nClass, sClass2da, 60 * cwThisAssignment.nWeightDefences);
            }

            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_MAGIC_MISSILE, nClass, sClass2da, (10 + nCasterLevel * 4) * cwThisAssignment.nWeightDamagingSingleTarget, METAMAGIC_EMPOWER);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_HORIZIKAULS_BOOM, nClass, sClass2da, (8 + nSpellFocusEvocation + nCasterLevel * 4) * cwThisAssignment.nWeightDamagingSingleTarget, METAMAGIC_EMPOWER);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_ICE_DAGGER, nClass, sClass2da, (18 + nCasterLevel) * cwThisAssignment.nWeightDamagingSingleTarget, METAMAGIC_EMPOWER);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_NEGATIVE_ENERGY_RAY, nClass, sClass2da, (8 + nSpellFocusNecromancy + nCasterLevel * 4) * cwThisAssignment.nWeightDamagingSingleTarget, METAMAGIC_EMPOWER);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_RAY_OF_ENFEEBLEMENT, nClass, sClass2da, (20 * nSpellFocusNecromancy * 8) * cwThisAssignment.nWeightControlSingleTarget, METAMAGIC_EMPOWER);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_BLINDNESS_AND_DEAFNESS, nClass, sClass2da, (26 + nSpellFocusEnchantment * 8) * cwThisAssignment.nWeightControlSingleTarget, METAMAGIC_EXTEND);
            if (!GetHasSpell(SPELL_CLOUD_OF_BEWILDERMENT, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_CLOUD_OF_BEWILDERMENT, nClass, sClass2da, (26 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightControlAoENonSelective, METAMAGIC_EXTEND);
            }


            if (!bHasHaste)
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_HASTE, nClass, sClass2da, 60 * cwThisAssignment.nWeightOffensiveUtility);
            }
            if (!GetHasSpell(SPELL_IMPROVED_INVISIBILITY, oCreature) && !GetHasSpell(SPELL_DISPLACEMENT, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_DISPLACEMENT, nClass, sClass2da, 45 * cwThisAssignment.nWeightDefences);
            }


            if (!bHasSummon)
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SUMMON_CREATURE_III, nClass, sClass2da, 40 * cwThisAssignment.nHighestCategoryWeight);
            }
            if (!bHasDamageShield)
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_DEATH_ARMOR, nClass, sClass2da, 30 * cwThisAssignment.nWeightDefences, METAMAGIC_EXTEND);
            }
            jObj = _AddSpellFromTempArrays(oCreature, nClass, nWeightSum, jObj);
            nAdded = JsonGetInt(JsonObjectGet(jObj, "LastAdded"));
            if (nAdded == SPELL_SUMMON_CREATURE_III)
            {
                bHasSummon = 1;
            }
            if (nAdded == SPELL_DEATH_ARMOR)
            {
                bHasDamageShield = 1;
            }
            if (nAdded == SPELL_HASTE)
            {
                bHasHaste = 1;
            }
            nAssigned++;
            nLeft--;
        }

        nLeft = Array_At_Int(RAND_SPELL_SLOTS_REMAINING, 2);
        nAssigned = 0;
        while (nLeft > 0)
        {
            cwThisAssignment = _CalculateWeightForSpellAssignment(cwWeights, nAssigned);
             nWeightSum = 0;
            _ClearRandomSpellTempArrays();
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_BALAGARNSIRONHORN, nClass, sClass2da, (15 * nSpellFocusEnchantment * 8) * cwThisAssignment.nWeightControlAoENonSelective);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_BLINDNESS_AND_DEAFNESS, nClass, sClass2da, (26 + nSpellFocusEnchantment * 8) * cwThisAssignment.nWeightControlSingleTarget);
            if (!GetHasSpell(SPELL_CLOUD_OF_BEWILDERMENT, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_CLOUD_OF_BEWILDERMENT, nClass, sClass2da, (26 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightControlAoENonSelective);
            }
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_COMBUST, nClass, sClass2da, (20 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightDamagingSingleTarget);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_GEDLEES_ELECTRIC_LOOP, nClass, sClass2da, (20 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightDamagingSingleTarget);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_MELFS_ACID_ARROW, nClass, sClass2da, (20 + nCasterLevel) * cwThisAssignment.nWeightDamagingSingleTarget);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_GHOUL_TOUCH, nClass, sClass2da, (20 + nSpellFocusNecromancy * 8) * cwThisAssignment.nWeightControlSingleTarget);
            if (!GetHasSpell(SPELL_SEE_INVISIBILITY, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SEE_INVISIBILITY, nClass, sClass2da, 7 * cwThisAssignment.nWeightOffensiveUtility);
            }
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_TASHAS_HIDEOUS_LAUGHTER, nClass, sClass2da, (15 * nSpellFocusEnchantment * 8) * cwThisAssignment.nWeightControlSingleTarget);
            if (!GetHasSpell(SPELL_WEB, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_WEB, nClass, sClass2da, (26 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightControlAoENonSelective);
            }
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_LESSER_DISPEL, nClass, sClass2da, (2 - GetHasSpell(SPELL_LESSER_DISPEL, oCreature)) * 15 * cwThisAssignment.nWeightOffensiveUtility);
            if (!GetHasSpell(SPELL_IMPROVED_INVISIBILITY, oCreature) && !GetHasSpell(SPELL_ETHEREAL_VISAGE, oCreature) && !GetHasSpell(SPELL_DISPLACEMENT, oCreature) && !GetHasSpell(SPELL_GHOSTLY_VISAGE, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_GHOSTLY_VISAGE, nClass, sClass2da, 30 * cwThisAssignment.nWeightDefences);
            }
            if (!GetHasSpell(SPELL_ENERGY_BUFFER, oCreature) && !GetHasSpell(SPELL_PROTECTION_FROM_ELEMENTS, oCreature) && !GetHasSpell(SPELL_RESIST_ELEMENTS, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_RESIST_ELEMENTS, nClass, sClass2da, 60 * cwThisAssignment.nWeightDefences);
            }
            if (!GetHasSpell(SPELL_STONE_BONES, oCreature) && GetRacialType(oCreature) == RACIAL_TYPE_UNDEAD)
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_STONE_BONES, nClass, sClass2da, 50 * cwThisAssignment.nWeightDefences);
            }

            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_GREASE, nClass, sClass2da, (20 + nCasterLevel + nSpellFocusConjuration * 3) * cwThisAssignment.nWeightControlAoENonSelective, METAMAGIC_EXTEND);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_RAY_OF_ENFEEBLEMENT, nClass, sClass2da, (20 * nSpellFocusNecromancy * 8) * cwThisAssignment.nWeightControlSingleTarget, METAMAGIC_EXTEND);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_CHARM_PERSON, nClass, sClass2da, (26 + nSpellFocusEnchantment * 8) * cwThisAssignment.nWeightControlSingleTarget, METAMAGIC_EXTEND);


           if (nClass == CLASS_TYPE_WIZARD)
            {
                if (!GetHasSpell(SPELL_FOXS_CUNNING, oCreature))
                {
                    nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_FOXS_CUNNING, nClass, sClass2da, 60 * cwThisAssignment.nWeightOffensiveUtility);
                }
            }
            else
            {
                if (!GetHasSpell(SPELL_EAGLE_SPLEDOR, oCreature))
                {
                    nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_EAGLE_SPLEDOR, nClass, sClass2da, 60 * cwThisAssignment.nWeightOffensiveUtility);
                }
            }

            if (!bHasSummon)
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SUMMON_CREATURE_II, nClass, sClass2da, 40 * cwThisAssignment.nHighestCategoryWeight);
            }
            if (!bHasDamageShield)
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_DEATH_ARMOR, nClass, sClass2da, 30 * cwThisAssignment.nWeightDefences);
            }
            jObj = _AddSpellFromTempArrays(oCreature, nClass, nWeightSum, jObj);
            nAdded = JsonGetInt(JsonObjectGet(jObj, "LastAdded"));
            if (nAdded == SPELL_SUMMON_CREATURE_II)
            {
                bHasSummon = 1;
            }
            if (nAdded == SPELL_DEATH_ARMOR)
            {
                bHasDamageShield = 1;
            }
            nAssigned++;
            nLeft--;
        }

        nLeft = Array_At_Int(RAND_SPELL_SLOTS_REMAINING, 1);
        nAssigned = 0;
        while (nLeft > 0)
        {
            cwThisAssignment = _CalculateWeightForSpellAssignment(cwWeights, nAssigned);
             nWeightSum = 0;
            _ClearRandomSpellTempArrays();
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_GREASE, nClass, sClass2da, (20 + nCasterLevel + nSpellFocusConjuration * 3) * cwThisAssignment.nWeightControlAoENonSelective);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_BURNING_HANDS, nClass, sClass2da, (28 + nSpellFocusTransmutation * 8) * cwThisAssignment.nWeightDamagingAoENonSelective);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_CHARM_PERSON, nClass, sClass2da, (26 + nSpellFocusEnchantment * 8) * cwThisAssignment.nWeightControlSingleTarget);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_COLOR_SPRAY, nClass, sClass2da, (26 + nSpellFocusIllusion * 8) * cwThisAssignment.nWeightControlAoENonSelective);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SLEEP, nClass, sClass2da, (20 - (nCasterLevel * 2) + (nSpellFocusEnchantment * 3)) * cwThisAssignment.nWeightControlAoENonSelective);
            // Horizikaul - 1d4 per 2 levels, no save for damage, max 5d4
            // Magic missile: 1d4+1 per 2 levels, no save, max 5d4 + 5
            // Ice dagger: 1d4 per level, max 5d4, reflex half
            // Negative energy ray: 1d6 per 2 levels, max 5d6, will half
            // -> ice dagger is significantly better at low levels but falls off pretty rapidly
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_HORIZIKAULS_BOOM, nClass, sClass2da,(18 + nSpellFocusEvocation + nCasterLevel * 4) * cwThisAssignment.nWeightDamagingSingleTarget);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_ICE_DAGGER, nClass, sClass2da, (28 + nCasterLevel) * cwThisAssignment.nWeightDamagingSingleTarget);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_MAGIC_MISSILE, nClass, sClass2da, (20 + nCasterLevel * 4) * cwThisAssignment.nWeightDamagingSingleTarget);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_NEGATIVE_ENERGY_RAY, nClass, sClass2da, (18 + nSpellFocusNecromancy * 2 + nCasterLevel * 4) * cwThisAssignment.nWeightDamagingSingleTarget);
            // If you're thinking of summoning demons, do not leave home without protection from evil. Ever.
            if (GetHasSpell(SPELL_GATE, oCreature) && !GetHasSpell(SPELL_PROTECTION_FROM_EVIL, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_PROTECTION_FROM_EVIL, nClass, sClass2da, 99999);
            }
            if (GetAlignmentGoodEvil(oCreature) != ALIGNMENT_GOOD)
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_PROTECTION_FROM_GOOD, nClass, sClass2da, 30 * cwThisAssignment.nWeightDefences);
            }
            if (GetAlignmentGoodEvil(oCreature) != ALIGNMENT_EVIL)
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_PROTECTION_FROM_EVIL, nClass, sClass2da, 5 * cwThisAssignment.nWeightDefences);
            }
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_RAY_OF_ENFEEBLEMENT, nClass, sClass2da, (20 + nSpellFocusNecromancy * 8) * cwThisAssignment.nWeightControlSingleTarget);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SCARE, nClass, sClass2da, (5 - nCasterLevel) * (20 + nSpellFocusNecromancy * 8) * cwThisAssignment.nWeightControlSingleTarget);
            if (!GetHasSpell(SPELL_SHIELD, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SHIELD, nClass, sClass2da, 30 * cwThisAssignment.nWeightDefences);
            }
            if (!GetHasSpell(SPELL_MAGE_ARMOR, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_MAGE_ARMOR, nClass, sClass2da, 30 * cwThisAssignment.nWeightDefences);
            }

            if (!bHasSummon)
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SUMMON_CREATURE_I, nClass, sClass2da, 40 * cwThisAssignment.nHighestCategoryWeight);
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SHELGARNS_PERSISTENT_BLADE, nClass, sClass2da, 40 * cwThisAssignment.nHighestCategoryWeight);
            }
            jObj = _AddSpellFromTempArrays(oCreature, nClass, nWeightSum, jObj);
            nAdded = JsonGetInt(JsonObjectGet(jObj, "LastAdded"));
            if (nAdded == SPELL_SUMMON_CREATURE_I || nAdded == SPELL_SHELGARNS_PERSISTENT_BLADE)
            {
                bHasSummon = 1;
            }
            nAssigned++;
            nLeft--;
        }

        nLeft = Array_At_Int(RAND_SPELL_SLOTS_REMAINING, 0);
        nAssigned = 0;
        while (nLeft > 0)
        {
            cwThisAssignment = _CalculateWeightForSpellAssignment(cwWeights, nAssigned);
            nWeightSum = 0;
            _ClearRandomSpellTempArrays();
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_LIGHT, nClass, sClass2da, 1);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_FLARE, nClass, sClass2da, (20 + nSpellFocusEvocation * 2) * cwThisAssignment.nWeightControlSingleTarget);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_RAY_OF_FROST, nClass, sClass2da, 30 * cwThisAssignment.nWeightDamagingSingleTarget);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_ACID_SPLASH, nClass, sClass2da, 20 * cwThisAssignment.nWeightDamagingSingleTarget);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_ELECTRIC_JOLT, nClass, sClass2da, 20 * cwThisAssignment.nWeightDamagingSingleTarget);
            if (!GetHasSpell(SPELL_RESISTANCE, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_RESISTANCE, nClass, sClass2da, 80 * cwThisAssignment.nWeightDefences);
            }
            jObj = _AddSpellFromTempArrays(oCreature, nClass, nWeightSum, jObj);
            nAdded = JsonGetInt(JsonObjectGet(jObj, "LastAdded"));;
            nAssigned++;
            nLeft--;
        }
    }
    else
    {
        // Bard
        // Spontaneous casting is implied, no need to metamagic or GetHasSpell for dupes as taking multiples is impossible anyway
        nLeft = Array_At_Int(RAND_SPELL_SLOTS_REMAINING, 6);
        nAssigned = 0;
        while (nLeft > 0)
        {
            cwThisAssignment = _CalculateWeightForSpellAssignment(cwWeights, nAssigned);
             nWeightSum = 0;
            _ClearRandomSpellTempArrays();
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_DIRGE, nClass, sClass2da,  30 * cwThisAssignment.nWeightMeleeAbility);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_ENERGY_BUFFER, nClass, sClass2da,  50 * cwThisAssignment.nWeightDefences);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_ICE_STORM, nClass, sClass2da,  30 * cwThisAssignment.nWeightDamagingAoENonSelective);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_MASS_HASTE, nClass, sClass2da, 60 * cwThisAssignment.nWeightOffensiveUtility);
            if (!bHasSummon)
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SUMMON_CREATURE_VI, nClass, sClass2da, 40 * cwThisAssignment.nHighestCategoryWeight);
            }
            jObj = _AddSpellFromTempArrays(oCreature, nClass, nWeightSum, jObj);
            nAdded = JsonGetInt(JsonObjectGet(jObj, "LastAdded"));
            if (nAdded == SPELL_SUMMON_CREATURE_VI)
            {
                bHasSummon = 1;
            }
            if (nAdded == SPELL_MASS_HASTE)
            {
                bHasHaste = 1;
            }
            nAssigned++;
            nLeft--;
        }
        
        nLeft = Array_At_Int(RAND_SPELL_SLOTS_REMAINING, 5);
        nAssigned = 0;
        while (nLeft > 0)
        {
            cwThisAssignment = _CalculateWeightForSpellAssignment(cwWeights, nAssigned);
             nWeightSum = 0;
            _ClearRandomSpellTempArrays();
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_ETHEREAL_VISAGE, nClass, sClass2da,  50 * cwThisAssignment.nWeightDefences);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_GREATER_DISPELLING, nClass, sClass2da,  30 * cwThisAssignment.nWeightOffensiveUtility);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_HEALING_CIRCLE, nClass, sClass2da,  20 * cwThisAssignment.nWeightCureConditions);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_MIND_FOG, nClass, sClass2da, (26 + nSpellFocusEnchantment * 8)  * cwThisAssignment.nWeightControlAoENonSelective);
            if (!bHasSummon)
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SUMMON_CREATURE_V, nClass, sClass2da, 40 * cwThisAssignment.nHighestCategoryWeight);
            }
            jObj = _AddSpellFromTempArrays(oCreature, nClass, nWeightSum, jObj);
            nAdded = JsonGetInt(JsonObjectGet(jObj, "LastAdded"));
            if (nAdded == SPELL_SUMMON_CREATURE_V)
            {
                bHasSummon = 1;
            }
            nAssigned++;
            nLeft--;
        }
        
        nLeft = Array_At_Int(RAND_SPELL_SLOTS_REMAINING, 4);
        nAssigned = 0;
        while (nLeft > 0)
        {
            cwThisAssignment = _CalculateWeightForSpellAssignment(cwWeights, nAssigned);
             nWeightSum = 0;
            _ClearRandomSpellTempArrays();
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_DISMISSAL, nClass, sClass2da,  10 * cwThisAssignment.nWeightDamagingAoENonSelective);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_CHARM_MONSTER, nClass, sClass2da, (26 + nSpellFocusEnchantment * 8) * cwThisAssignment.nWeightControlSingleTarget);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_CLAIRAUDIENCE_AND_CLAIRVOYANCE, nClass, sClass2da, 5 * cwThisAssignment.nWeightOffensiveUtility);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_CONFUSION, nClass, sClass2da, (26 + nSpellFocusEnchantment * 8) * cwThisAssignment.nWeightControlAoENonSelective);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_CURE_CRITICAL_WOUNDS, nClass, sClass2da,  20 * cwThisAssignment.nWeightCureConditions);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_NEUTRALIZE_POISON, nClass, sClass2da,  15 * cwThisAssignment.nWeightCureConditions);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_WAR_CRY, nClass, sClass2da, (18 + nSpellFocusEnchantment * 8)  * (cwThisAssignment.nWeightControlAoESelective + 
            cwThisAssignment.nWeightMeleeAbility));
            if (!bHasSummon)
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SUMMON_CREATURE_IV, nClass, sClass2da, 40 * cwThisAssignment.nHighestCategoryWeight);
            }
            jObj = _AddSpellFromTempArrays(oCreature, nClass, nWeightSum, jObj);
            nAdded = JsonGetInt(JsonObjectGet(jObj, "LastAdded"));
            if (nAdded == SPELL_SUMMON_CREATURE_IV)
            {
                bHasSummon = 1;
            }
            nAssigned++;
            nLeft--;
        }
            
            
        
        nLeft = Array_At_Int(RAND_SPELL_SLOTS_REMAINING, 3);
        nAssigned = 0;
        while (nLeft > 0)
        {
            cwThisAssignment = _CalculateWeightForSpellAssignment(cwWeights, nAssigned);
             nWeightSum = 0;
            _ClearRandomSpellTempArrays();
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_BESTOW_CURSE, nClass, sClass2da, (16 + nSpellFocusTransmutation * 8) * cwThisAssignment.nWeightControlSingleTarget);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_IMPROVED_INVISIBILITY, nClass, sClass2da,  100 * cwThisAssignment.nWeightDefences);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_DOMINATE_PERSON, nClass, sClass2da,  (26 + nSpellFocusEnchantment * 8) * cwThisAssignment.nWeightControlSingleTarget);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_HOLD_MONSTER, nClass, sClass2da,  (26 + nSpellFocusEnchantment * 8) * cwThisAssignment.nWeightControlSingleTarget);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_CURE_SERIOUS_WOUNDS, nClass, sClass2da,  20 * cwThisAssignment.nWeightCureConditions);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_DISPEL_MAGIC, nClass, sClass2da,  30 * cwThisAssignment.nWeightOffensiveUtility);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_DISPLACEMENT, nClass, sClass2da, 45 * cwThisAssignment.nWeightDefences);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_FEAR, nClass, sClass2da, (26 + nSpellFocusNecromancy * 8) * cwThisAssignment.nWeightControlAoENonSelective);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_GREATER_MAGIC_WEAPON, nClass, sClass2da, 20 * cwThisAssignment.nWeightMeleeAbility);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_GUST_OF_WIND, nClass, sClass2da, (20 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightControlAoENonSelective);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_INVISIBILITY_SPHERE, nClass, sClass2da, 20 * cwThisAssignment.nWeightDefences);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_WOUNDING_WHISPERS, nClass, sClass2da, 20 * cwThisAssignment.nWeightDefences);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_KEEN_EDGE, nClass, sClass2da, 20 * cwThisAssignment.nWeightMeleeAbility);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_MAGIC_CIRCLE_AGAINST_ALIGNMENT, nClass, sClass2da, 20 * cwThisAssignment.nWeightDefences);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_REMOVE_CURSE, nClass, sClass2da, 5 * cwThisAssignment.nWeightCureConditions);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_REMOVE_DISEASE, nClass, sClass2da, 5 * cwThisAssignment.nWeightCureConditions);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SLOW, nClass, sClass2da, (26 + nSpellFocusTransmutation * 8) * cwThisAssignment.nWeightControlAoESelective);
            if (!GetHasSpell(SPELL_MASS_HASTE, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_HASTE, nClass, sClass2da, 60 * cwThisAssignment.nWeightOffensiveUtility);
            }
            if (!bHasSummon)
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SUMMON_CREATURE_III, nClass, sClass2da, 40 * cwThisAssignment.nHighestCategoryWeight);
            }
            jObj = _AddSpellFromTempArrays(oCreature, nClass, nWeightSum, jObj);
            nAdded = JsonGetInt(JsonObjectGet(jObj, "LastAdded"));
            if (nAdded == SPELL_SUMMON_CREATURE_III)
            {
                bHasSummon = 1;
            }
            nAssigned++;
            nLeft--;
        }
        
        nLeft = Array_At_Int(RAND_SPELL_SLOTS_REMAINING, 2);
        nAssigned = 0;
        while (nLeft > 0)
        {
            cwThisAssignment = _CalculateWeightForSpellAssignment(cwWeights, nAssigned);
             nWeightSum = 0;
            _ClearRandomSpellTempArrays();
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_BLINDNESS_AND_DEAFNESS, nClass, sClass2da, (26 + nSpellFocusEnchantment * 8) * cwThisAssignment.nWeightControlSingleTarget);
            if (!GetHasSpell(SPELL_EAGLE_SPLEDOR, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_BULLS_STRENGTH, nClass, sClass2da, 40 * cwThisAssignment.nWeightMeleeAbility);
            }
            if (!GetHasSpell(SPELL_BULLS_STRENGTH))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_EAGLE_SPLEDOR, nClass, sClass2da, 40 * cwThisAssignment.nWeightControlSingleTarget);
            }
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_CLARITY, nClass, sClass2da,  10 * cwThisAssignment.nWeightDefences);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_CLOUD_OF_BEWILDERMENT, nClass, sClass2da, (26 + nSpellFocusEvocation * 8) * cwThisAssignment.nWeightControlAoENonSelective);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_CURE_MODERATE_WOUNDS, nClass, sClass2da,  20 * cwThisAssignment.nWeightCureConditions);
            
            if (!GetHasSpell(SPELL_ETHEREAL_VISAGE, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_GHOSTLY_VISAGE, nClass, sClass2da,  20 * cwThisAssignment.nWeightDefences);
            }
            
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_HOLD_PERSON, nClass, sClass2da,  (26 + nSpellFocusEnchantment * 8) * cwThisAssignment.nWeightControlSingleTarget);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SEE_INVISIBILITY, nClass, sClass2da,  5 * cwThisAssignment.nWeightOffensiveUtility);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SILENCE, nClass, sClass2da,  (20 + nSpellFocusIllusion * 8) * cwThisAssignment.nWeightControlAoENonSelective);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SOUND_BURST, nClass, sClass2da, 10 * cwThisAssignment.nWeightControlSingleTarget);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_TASHAS_HIDEOUS_LAUGHTER, nClass, sClass2da, (15 * nSpellFocusEnchantment * 8) * cwThisAssignment.nWeightControlSingleTarget);
            
            if (!bHasSummon)
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SUMMON_CREATURE_II, nClass, sClass2da, 40 * cwThisAssignment.nHighestCategoryWeight);
            }
            jObj = _AddSpellFromTempArrays(oCreature, nClass, nWeightSum, jObj);
            nAdded = JsonGetInt(JsonObjectGet(jObj, "LastAdded"));
            if (nAdded == SPELL_SUMMON_CREATURE_II)
            {
                bHasSummon = 1;
            }
            nAssigned++;
            nLeft--;
        }
        
        nLeft = Array_At_Int(RAND_SPELL_SLOTS_REMAINING, 1);
        nAssigned = 0;
        while (nLeft > 0)
        {
            cwThisAssignment = _CalculateWeightForSpellAssignment(cwWeights, nAssigned);
             nWeightSum = 0;
            _ClearRandomSpellTempArrays();
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_AMPLIFY, nClass, sClass2da, 5 * cwThisAssignment.nWeightOffensiveUtility);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_BALAGARNSIRONHORN, nClass, sClass2da, (15 * nSpellFocusEnchantment * 8) * cwThisAssignment.nWeightControlAoENonSelective);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_CHARM_PERSON, nClass, sClass2da, (26 + nSpellFocusEnchantment * 8) * cwThisAssignment.nWeightControlSingleTarget);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_CURE_LIGHT_WOUNDS, nClass, sClass2da,  20 * cwThisAssignment.nWeightCureConditions);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_GREASE, nClass, sClass2da, (20 + nCasterLevel + nSpellFocusConjuration * 3) * cwThisAssignment.nWeightControlAoENonSelective);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_LESSER_DISPEL, nClass, sClass2da, 30 * cwThisAssignment.nWeightOffensiveUtility);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_MAGE_ARMOR, nClass, sClass2da, 30 * cwThisAssignment.nWeightDefences);
            if (!GetHasSpell(SPELL_MAGIC_WEAPON, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_MAGIC_WEAPON, nClass, sClass2da, 20 * cwThisAssignment.nWeightOffensiveUtility);   
            }
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SCARE, nClass, sClass2da, (5 - nCasterLevel) * (20 + nSpellFocusNecromancy * 8) * cwThisAssignment.nWeightControlSingleTarget);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SLEEP, nClass, sClass2da, (20 - (nCasterLevel * 2) + (nSpellFocusEnchantment * 3)) * cwThisAssignment.nWeightControlAoENonSelective);

            if (!bHasSummon)
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_SUMMON_CREATURE_I, nClass, sClass2da, 40 * cwThisAssignment.nHighestCategoryWeight);
            }
            jObj = _AddSpellFromTempArrays(oCreature, nClass, nWeightSum, jObj);
            nAdded = JsonGetInt(JsonObjectGet(jObj, "LastAdded"));
            if (nAdded == SPELL_SUMMON_CREATURE_I)
            {
                bHasSummon = 1;
            }
            nAssigned++;
            nLeft--;
        }
        
        nLeft = Array_At_Int(RAND_SPELL_SLOTS_REMAINING, 0);
        nAssigned = 0;
        while (nLeft > 0)
        {
            cwThisAssignment = _CalculateWeightForSpellAssignment(cwWeights, nAssigned);
            nWeightSum = 0;
            _ClearRandomSpellTempArrays();
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_LIGHT, nClass, sClass2da, 1);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_FLARE, nClass, sClass2da, (20 + nSpellFocusEvocation * 2) * cwThisAssignment.nWeightControlSingleTarget);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_DAZE, nClass, sClass2da, 30 * cwThisAssignment.nWeightControlSingleTarget);
            nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_CURE_MINOR_WOUNDS, nClass, sClass2da, 10 * cwThisAssignment.nWeightCureConditions);
            if (!GetHasSpell(SPELL_RESISTANCE, oCreature))
            {
                nWeightSum += _AddToRandomSpellTempArrays(oCreature, SPELL_RESISTANCE, nClass, sClass2da, 80 * cwThisAssignment.nWeightDefences);
            }
            jObj = _AddSpellFromTempArrays(oCreature, nClass, nWeightSum, jObj);
            nAdded = JsonGetInt(JsonObjectGet(jObj, "LastAdded"));;
            nAssigned++;
            nLeft--;
        }
            
    }
    
    jObj = JsonObjectSet(jObj, "Feats", jFeats);
    int nFeatsLength = JsonGetLength(jFeats);
    for (i=0; i<nFeatsLength; i++)
    {
        json jFeat = JsonArrayGet(jFeats, i);
        int nFeat = JsonGetInt(jFeat);
        NWNX_Creature_RemoveFeat(oCreature, nFeat);
    }
    int nSpellbookIndex = GetCampaignInt("randspellbooks", GetResRef(oCreature) + "_numsbs_" + IntToString(nClass));
    //WriteTimestampedLogEntry("Set to " + GetResRef(oCreature) + "_randspellbook_" + IntToString(nClass) + "_" + IntToString(nSpellbookIndex));
    //WriteTimestampedLogEntry(JsonDump(jObj));
    SetCampaignJson("randspellbooks", GetResRef(oCreature) + "_rsb_" + IntToString(nClass) + "_" + IntToString(nSpellbookIndex), jObj);
    SetCampaignInt("randspellbooks", GetResRef(oCreature) + "_numsbs_" + IntToString(nClass), nSpellbookIndex + 1);
    SetLocalInt(oCreature, "rand_feat_caster", nCasterFeats);
    NWNX_Util_SetInstructionsExecuted(0);
    
}

void _RandomSpellbookPopulateDivine(int nSpellbookType, object oCreature, int nClass)
{
    // TODO
}


void RandomSpellbookPopulate(int nSpellbookType, object oCreature, int nClass)
{
    //WriteTimestampedLogEntry("Populating random spellbook of type " + IntToString(nSpellbookType) + " for " + GetName(oCreature) + " and class " + IntToString(nClass));
    _GetAvailableSpellSlots(oCreature, nClass);
    if (nSpellbookType < RAND_SPELL_DIVINE_START)
    {
        _RandomSpellbookPopulateArcane(nSpellbookType, oCreature, nClass);
    }
    else
    {
        _RandomSpellbookPopulateDivine(nSpellbookType, oCreature, nClass);
    }
}

void LoadSpellbook(int nClass, object oCreature=OBJECT_SELF, int nFixedIndex=-1)
{
    if (nFixedIndex == -1)
    {
        int nNumSpellbooks = GetCampaignInt("randspellbooks", GetResRef(oCreature) + "_numsbs_" + IntToString(nClass));
        nFixedIndex = Random(nNumSpellbooks);
    }
    
    WriteTimestampedLogEntry("Retrieve:" + GetResRef(oCreature) + "_rsb_" + IntToString(nClass) + "_" + IntToString(nFixedIndex));
    // Resref: 16
    // _rsb_ : 5
    // nClass: 2
    // _: 1
    // nFixedIndex: 2, or maybe 3 if someone is insane
    // = 26 or 27 at a stretch, max for campaign db is 32
    json jObj = GetCampaignJson("randspellbooks", GetResRef(oCreature) + "_rsb_" + IntToString(nClass) + "_" + IntToString(nFixedIndex));
    WriteTimestampedLogEntry(JsonDump(jObj));
    int nNumCasterFeats = GetLocalInt(oCreature, "rand_feat_caster");
    int i;
    json jFeats = JsonObjectGet(jObj, "Feats");
    // The feat processor sets rand_feat_caster and will add random other feats if this fails to fill all the slots
    for (i=0; i<nNumCasterFeats; i++)
    {
        json jFeat = JsonArrayGet(jFeats, i);
        if (i >= JsonGetLength(jFeats)) { break; }
        int nFeat = JsonGetInt(jFeat);
        NWNX_Creature_AddFeat(oCreature, nFeat);
        SetLocalInt(oCreature, "rand_feat_caster", GetLocalInt(oCreature, "rand_feat_caster")-1);
    }
    
    for(i=0; i<=9; i++)
    {
        json jSpells = JsonObjectGet(jObj, IntToString(i));
        int nSpellIndex = 0;
        for (nSpellIndex=0; nSpellIndex < JsonGetLength(jSpells); nSpellIndex++)
        {
            json jSpellData = JsonArrayGet(jSpells, nSpellIndex);
            int nSpell = JsonGetInt(JsonObjectGet(jSpellData, "id"));
            int nMetamagic = JsonGetInt(JsonObjectGet(jSpellData, "metamagic"));
            int nDomain = JsonGetInt(JsonObjectGet(jSpellData, "domain"));
            if (nClass == CLASS_TYPE_SORCERER || nClass == CLASS_TYPE_BARD)
            {
                //WriteTimestampedLogEntry("Add spont known spell " + IntToString(nThisSpell) + " at lvl " + IntToString(nThisLevel));
                NWNX_Creature_AddKnownSpell(oCreature, nClass, i, nSpell);
            }
            else
            {
                struct NWNX_Creature_MemorisedSpell mem;
                mem.id = nSpell;
                mem.ready = 1;
                mem.meta = nMetamagic;
                mem.domain = nDomain;
                int nIndex = nSpellIndex;
                NWNX_Creature_SetMemorisedSpell(oCreature, nClass, i, nIndex, mem);
            }
        }
    }
}

void SeedingSpellbooksComplete(object oCreature=OBJECT_SELF)
{
    SetLocalInt(oCreature, "seed_spellbook_complete", 1);
}

// void main(){}
