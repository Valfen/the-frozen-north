void BashLock(object oAttacker)
{
    int nUnlockDC = GetLockUnlockDC(OBJECT_SELF);

// return and remove the script from itself if locked, plot, key required, and no key tag
    if (GetLocked(OBJECT_SELF) && GetPlotFlag(OBJECT_SELF) && GetLockKeyRequired(OBJECT_SELF) && GetLockKeyTag(OBJECT_SELF) == "")
    {
        SetEventScript(OBJECT_SELF, EVENT_SCRIPT_DOOR_ON_MELEE_ATTACKED, "");
        return;
    }

// return if not locked or low unlock DC
    if (!GetLocked(OBJECT_SELF) || nUnlockDC < 10) return;

    int nStrengthBonus = GetAbilityModifier(ABILITY_STRENGTH, oAttacker);

    if (GetActionMode(oAttacker, ACTION_MODE_IMPROVED_POWER_ATTACK))
    {
        nStrengthBonus = nStrengthBonus + 4;
    }
    else if (GetActionMode(oAttacker, ACTION_MODE_POWER_ATTACK))
    {
        nStrengthBonus = nStrengthBonus + 2;
    }

    if (nStrengthBonus < -7) nStrengthBonus = -7;

    int nRoll = d20();

    int nTotal = nRoll + nStrengthBonus;

    int nEffect;

    string sSign;

    if (nStrengthBonus >= 0)
    {
        sSign = "+";
    }
    else
    {
        sSign = "-";
    }


    string sOutcome;
    if (20+nStrengthBonus < nUnlockDC)
    {
        sOutcome = "Success will never be possible";
        nEffect = VFX_COM_BLOOD_SPARK_SMALL;
    }
    if (nTotal >= nUnlockDC)
    {
        sOutcome = "success";
        SetLocked(OBJECT_SELF, FALSE);
        nEffect = VFX_COM_BLOOD_SPARK_LARGE;
        AssignCommand(oAttacker, ClearAllActions(TRUE));

        PlaySound("cb_bu_metallrg");

        switch(GetObjectType(OBJECT_SELF))
        {
            case OBJECT_TYPE_DOOR: ActionOpenDoor(OBJECT_SELF); break;
            case OBJECT_TYPE_PLACEABLE: ActionPlayAnimation(ANIMATION_PLACEABLE_OPEN); break;
        }
    }
    else
    {
        sOutcome = "failure";
        nEffect = VFX_COM_BLOOD_SPARK_MEDIUM;
    }

    ApplyEffectToObject(DURATION_TYPE_INSTANT, EffectVisualEffect(nEffect), OBJECT_SELF);
    ApplyEffectToObject(DURATION_TYPE_INSTANT, EffectVisualEffect(nEffect), OBJECT_SELF);
    ApplyEffectToObject(DURATION_TYPE_INSTANT, EffectVisualEffect(nEffect), OBJECT_SELF);

    FloatingTextStringOnCreature("Bash Lock: *"+sOutcome+"* : ("+IntToString(nRoll)+" "+sSign+" "+IntToString(abs(nStrengthBonus))+" = "+IntToString(nTotal)+" vs. DC: "+IntToString(nUnlockDC)+")", oAttacker, FALSE);
}

void main()
{
    object oAttacker = GetLastAttacker();

// range weapons cannot be used for lock bashing
    if (GetWeaponRanged(GetLastWeaponUsed(oAttacker))) return;

    DelayCommand(0.2, BashLock(oAttacker));
}

