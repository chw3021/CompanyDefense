package io.github.chw3021.companydefense.skill;

import io.github.chw3021.companydefense.dto.SkillDto;
import io.github.chw3021.companydefense.skill.dv.AlgorithmCreationSkill;
import io.github.chw3021.companydefense.skill.dv.CodeExecutionSkill;
import io.github.chw3021.companydefense.skill.dv.CodeInterpretationSkill;
import io.github.chw3021.companydefense.skill.dv.DebuggingSkill;
import io.github.chw3021.companydefense.skill.dv.HackingDefenseSkill;
import io.github.chw3021.companydefense.skill.dv.ServerStabilizationSkill;
import io.github.chw3021.companydefense.skill.hr.BreakTimeSkill;
import io.github.chw3021.companydefense.skill.hr.CoffeeInfusionSkill;
import io.github.chw3021.companydefense.skill.hr.IrresistibleGossipSkill;
import io.github.chw3021.companydefense.skill.hr.OfficeSupportSkill;
import io.github.chw3021.companydefense.skill.hr.PerformancePressureSkill;
import io.github.chw3021.companydefense.skill.hr.WelfareCampaignSkill;
import io.github.chw3021.companydefense.stage.StageParent;

public class SkillFactory {
    public static SkillParent createSkill(SkillDto dto, StageParent stage) {
        if (dto.getSkillId().equals("dv1")) {
        	return new DebuggingSkill(dto, stage);
        }
        else if (dto.getSkillId().equals("dv2")) {
        	return new CodeExecutionSkill(dto, stage);
        }
        else if (dto.getSkillId().equals("dv3")) {
        	return new ServerStabilizationSkill(dto, stage);
        }
        else if (dto.getSkillId().equals("dv4")) {
        	return new AlgorithmCreationSkill(dto, stage);
        }
        else if (dto.getSkillId().equals("dv5_1")) {
        	return new CodeInterpretationSkill(dto, stage);
        }
        else if (dto.getSkillId().equals("dv5_2")) {
        	return new HackingDefenseSkill(dto, stage);
        }
        else if (dto.getSkillId().equals("hr1")) {
        	return new CoffeeInfusionSkill(dto, stage);
        }
        else if (dto.getSkillId().equals("hr2")) {
        	return new OfficeSupportSkill(dto, stage);
        }
        else if (dto.getSkillId().equals("hr3")) {
        	return new IrresistibleGossipSkill(dto, stage);
        }
        else if (dto.getSkillId().equals("hr4")) {
        	return new BreakTimeSkill(dto, stage);
        }
        else if (dto.getSkillId().equals("hr5_1")) {
        	return new PerformancePressureSkill(dto, stage);
        }
        else if (dto.getSkillId().equals("hr5_2")) {
        	return new WelfareCampaignSkill(dto, stage);
        }
        return new DebuggingSkill(dto, stage);
    }
}
