package io.github.chw3021.companydefense.skill;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.math.Vector2;
import com.badlogic.gdx.utils.Array;
import com.badlogic.gdx.utils.Timer;

import io.github.chw3021.companydefense.component.DamageComponent;
import io.github.chw3021.companydefense.dto.SkillDto;
import io.github.chw3021.companydefense.enemy.Enemy;
import io.github.chw3021.companydefense.screens.imagetools.PngAnimation;
import io.github.chw3021.companydefense.stage.StageParent;
import io.github.chw3021.companydefense.tower.Projectile;
import io.github.chw3021.companydefense.tower.Tower;


public abstract class SkillParent {
    protected String skillId;
    protected String skillName;
    protected String skillImagePath; //소환물 이미지 경로
    protected float mult;
    protected float duration;
    protected float cooldown;
    protected float range;
    protected float lastUsedTime = 0; // 마지막 사용 시간
    protected String summoneeImagePath; //소환물 이미지 경로
    protected String skillDescription; //스킬설명
    protected float baseCooldown;
    private PngAnimation effectAnimation;
    private Texture projectileTexture;

    public SkillParent(SkillDto dto) {
        this.skillId = dto.getSkillId();
        this.skillName = dto.getSkillName();
        this.mult = dto.getMult();
        this.duration = dto.getDuration();
        this.cooldown = dto.getCooldown();
        this.range = dto.getRange();
        this.skillImagePath = dto.getSkillImagePath();
        this.summoneeImagePath = dto.getSummoneeImagePath();
        this.baseCooldown = cooldown;
        this.skillDescription = dto.getSkillDescription();
        Gdx.app.postRunnable(() ->{
            this.effectAnimation = new PngAnimation(0.1f, summoneeImagePath, 640, 640, true);
            this.projectileTexture = new Texture(Gdx.files.internal(summoneeImagePath));
        });
    }
    private float elapsedTime = 0; // 🔹 경과 시간 추가

    public boolean canUse() { // 🔹 currentTime 파라미터 제거
        return elapsedTime >= cooldown; // 누적된 시간이 쿨타임을 초과했는지 확인
    }

    public void use(Tower tower, Array<Enemy> enemies) {
        if (!canUse()) return; // 🔹 currentTime 체크 방식 변경
        System.out.println(skillId);
        
        elapsedTime = 0; // 🔹 스킬 사용 후 경과 시간 초기화
        applyEffect(tower, enemies);
    }

    // 🔹 update 메서드 추가 (쿨타임을 경과 시간으로 체크)
    public void update(float delta) {
        elapsedTime += delta; // 🔹 매 프레임 경과 시간 누적
    }


    // 🔹 스킬 이펙트 애니메이션 표시
    protected void showSkillEffect(StageParent stage, float x, float y, float width, float height) {
    	if(effectAnimation == null) {
    		return;
    	}
        effectAnimation.setSize(width, height);
        effectAnimation.setPosition(x, y);

        stage.addActor(effectAnimation); // 스테이지에 애니메이션 추가

        // 지속 시간 후 제거
        Timer.schedule(new Timer.Task() {
            @Override
            public void run() {
                effectAnimation.remove();
            }
        }, duration);
    }

    // 🔹 스킬 이펙트 애니메이션 표시
    protected void showSkillEffect(StageParent stage, Vector2 v, float width, float height) {
    	if(effectAnimation == null) {
    		return;
    	}
        effectAnimation.setSize(width, height);
        effectAnimation.setPosition(v.x, v.y);

        stage.addActor(effectAnimation); // 스테이지에 애니메이션 추가

        // 지속 시간 후 제거
        Timer.schedule(new Timer.Task() {
            @Override
            public void run() {
                effectAnimation.remove();
            }
        }, duration);
    }


    // 🔹 스킬 투사체 발사
    protected void shotProjectile(StageParent stage, Vector2 start, Enemy target, DamageComponent damage, float width, float height) {
    	if(summoneeImagePath == null) {
    		return;
    	}

        Projectile projectile = new Projectile(projectileTexture, start, target, damage, width, height);

        stage.addActor(projectile); // 스테이지에 애니메이션 추가

        // 지속 시간 후 제거
        Timer.schedule(new Timer.Task() {
            @Override
            public void run() {
            	projectile.remove();
            }
        }, duration);
    }

    protected abstract void applyEffect(Tower tower, Array<Enemy> enemies);

	public float getCooldown() {
		return cooldown;
	}

	public void setCooldown(float f) {
		this.cooldown = f;
	}

	public float getBaseCooldown() {
		return baseCooldown;
	}
}
