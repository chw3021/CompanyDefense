package io.github.chw3021.companydefense.dto;

import java.util.List;

public class UserDto {
	private String userId;
	private String userName;
	private int userLevel = 1;
    private List<TowerOwnershipDto> userTowers;  // 타워와 레벨을 매핑
    private List<EquipmentOwnershipDto> userEquipments;  // 장비와 레벨을 매핑
	private List<MailDto> userMails;
	private int userHighScore;

    // 로그인 서비스 관련 필드
    private String loginProvider; // 예: "google", "ios", "guest", "kakao"
    private String externalId;    // 외부 서비스 ID (Google UID, Kakao UID 등)
    
	public String getUserId() {
		return userId;
	}
	public void setUserId(String userId) {
		this.userId = userId;
	}
	public String getUserName() {
		return userName;
	}
	public void setUserName(String userName) {
		this.userName = userName;
	}
	public int getUserLevel() {
		return userLevel;
	}
	public void setUserLevel(int userLevel) {
		this.userLevel = userLevel;
	}
	public List<TowerOwnershipDto> getUserTowers() {
		return userTowers;
	}
	public void setUserTowers(List<TowerOwnershipDto> userTowers) {
		this.userTowers = userTowers;
	}
	public List<EquipmentOwnershipDto> getUserEquipments() {
		return userEquipments;
	}
	public void setUserEquipments(List<EquipmentOwnershipDto> userEquipments) {
		this.userEquipments = userEquipments;
	}
	public List<MailDto> getUserMails() {
		return userMails;
	}
	public void setUserMails(List<MailDto> userMails) {
		this.userMails = userMails;
	}
	public int getUserHighScore() {
		return userHighScore;
	}
	public void setUserHighScore(int userHighScore) {
		this.userHighScore = userHighScore;
	}
	public String getLoginProvider() {
		return loginProvider;
	}
	public void setLoginProvider(String loginProvider) {
		this.loginProvider = loginProvider;
	}
	public String getExternalId() {
		return externalId;
	}
	public void setExternalId(String externalId) {
		this.externalId = externalId;
	}
    
    
}
