package io.github.chw3021.companydefense.dto;

public class SkillDto {
	private String skillId;
	private String skillName;
	private String skillImagePath; //소환물 이미지 경로
	private String skillDescription; //스킬설명
	private float mult;//수치
	private float duration;//지속시간
	private float cooldown;
	private float range;//범위, 반경
	private String summoneeImagePath; //소환물 이미지 경로
	
    public SkillDto() {}
    
	public String getSkillId() {
		return skillId;
	}
	public void setSkillId(String skillId) {
		this.skillId = skillId;
	}
	public String getSkillName() {
		return skillName;
	}
	public void setSkillName(String skillName) {
		this.skillName = skillName;
	}
	public float getMult() {
		return mult;
	}
	public void setMult(float mult) {
		this.mult = mult;
	}
	public float getDuration() {
		return duration;
	}
	public void setDuration(float duration) {
		this.duration = duration;
	}
	public float getCooldown() {
		return cooldown;
	}
	public void setCooldown(float cooldown) {
		this.cooldown = cooldown;
	}
	public float getRange() {
		return range;
	}
	public void setRange(float range) {
		this.range = range;
	}
	public String getSummoneeImagePath() {
		return summoneeImagePath;
	}
	public void setSummoneeImagePath(String summoneeImagePath) {
		this.summoneeImagePath = summoneeImagePath;
	}

	public String getSkillImagePath() {
		return skillImagePath;
	}

	public void setSkillImagePath(String skillImagePath) {
		this.skillImagePath = skillImagePath;
	}

	public String getSkillDescription() {
		return skillDescription;
	}

	public void setSkillDescription(String skillDescription) {
		this.skillDescription = skillDescription;
	}
	
	
}
