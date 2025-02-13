package io.github.chw3021.companydefense.skill.hr;

import com.badlogic.gdx.utils.Array;

import io.github.chw3021.companydefense.dto.SkillDto;
import io.github.chw3021.companydefense.enemy.Enemy;
import io.github.chw3021.companydefense.skill.SkillParent;
import io.github.chw3021.companydefense.stage.StageParent;
import io.github.chw3021.companydefense.tower.Tower;

public class WelfareCampaignSkill extends SkillParent {
	private StageParent stage;
	
	
    public WelfareCampaignSkill(SkillDto dto, StageParent stage) {
        super(dto);
        this.stage = stage;
    }

    @Override
    protected void applyEffect(Tower tower, Array<Enemy> enemies) {
        for (Tower ally : stage.towers) {
            ally.increaseAttackPower(mult, duration);
            ally.increaseAttackSpeed(mult, duration);
            showSkillEffect(stage, ally.getX(), ally.getY()+ally.getHeight()*0.2f, ally.getWidth()*0.4f, ally.getWidth()*0.4f);
        }
    }
}
