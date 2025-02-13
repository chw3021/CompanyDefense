package io.github.chw3021.companydefense.skill.hr;

import java.util.Random;

import com.badlogic.gdx.utils.Array;

import io.github.chw3021.companydefense.dto.SkillDto;
import io.github.chw3021.companydefense.enemy.Enemy;
import io.github.chw3021.companydefense.skill.SkillParent;
import io.github.chw3021.companydefense.stage.StageParent;
import io.github.chw3021.companydefense.tower.Tower;

public class IrresistibleGossipSkill extends SkillParent {
    private static final Random random = new Random();
	private StageParent stage;

    public IrresistibleGossipSkill(SkillDto dto, StageParent stage) {
        super(dto);
        this.stage = stage;
    }

    @Override
    protected void applyEffect(Tower tower, Array<Enemy> enemies) {
        Enemy enemy = tower.target;
        if(enemy != null) {
            if (random.nextFloat() <= mult) { // 확률 체크
                enemy.stun(duration);
            }
        }
        
    }
}
