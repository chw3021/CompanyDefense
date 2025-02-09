package io.github.chw3021.companydefense.dto;

public class TowerDto {
	private String towerId;
	private int towerLevel=1;
	private int towerGrade=1;
	private String towerName;
    private float towerPhysicalAttack;
    private float towerMagicAttack;
    private float towerAttackSpeed;
    private float towerAttackRange;
    private float towerAttackMult=0.1f;
	private String towerImagePath;
	private String towerAttackImagePath;
	private String towerPortraitPath;
    private String attackType = "closest";
    private String team;
    
	public String getTowerId() {
		return towerId;
	}
	public void setTowerId(String towerId) {
		this.towerId = towerId;
	}
	public int getTowerLevel() {
		return towerLevel;
	}
	public void setTowerLevel(int towerLevel) {
		this.towerLevel = towerLevel;
	}
	public int getTowerGrade() {
		return towerGrade;
	}
	public void setTowerGrade(int towerGrade) {
		this.towerGrade = towerGrade;
	}
	public String getTowerName() {
		return towerName;
	}
	public void setTowerName(String towerName) {
		this.towerName = towerName;
	}
	public float getTowerPhysicalAttack() {
		return towerPhysicalAttack;
	}
	public void setTowerPhysicalAttack(float towerPhysicalAttack) {
		this.towerPhysicalAttack = towerPhysicalAttack;
	}
	public float getTowerMagicAttack() {
		return towerMagicAttack;
	}
	public void setTowerMagicAttack(float towerMagicAttack) {
		this.towerMagicAttack = towerMagicAttack;
	}
	public float getTowerAttackSpeed() {
		return towerAttackSpeed;
	}
	public void setTowerAttackSpeed(float towerAttackSpeed) {
		this.towerAttackSpeed = towerAttackSpeed;
	}
	public float getTowerAttackRange() {
		return towerAttackRange;
	}
	public void setTowerAttackRange(float towerAttackRange) {
		this.towerAttackRange = towerAttackRange;
	}
	public String getTowerImagePath() {
		return towerImagePath;
	}
	public void setTowerImagePath(String towerImagePath) {
		this.towerImagePath = towerImagePath;
	}
	public String getAttackType() {
		return attackType;
	}
	public void setAttackType(String attackType) {
		this.attackType = attackType;
	}
	public float getTowerAttackMult() {
		return towerAttackMult;
	}
	public void setTowerAttackMult(float towerAttackMult) {
		this.towerAttackMult = towerAttackMult;
	}
	public String getTeam() {
		return team;
	}
	public void setTeam(String team) {
		this.team = team;
	}
	public String getTowerAttackImagePath() {
		return towerAttackImagePath;
	}
	public void setTowerAttackImagePath(String towerAttackImagePath) {
		this.towerAttackImagePath = towerAttackImagePath;
	}
	public String getTowerPortraitPath() {
		return towerPortraitPath;
	}
	public void setTowerPortraitPath(String towerPortraitPath) {
		this.towerPortraitPath = towerPortraitPath;
	}
    
    
}
