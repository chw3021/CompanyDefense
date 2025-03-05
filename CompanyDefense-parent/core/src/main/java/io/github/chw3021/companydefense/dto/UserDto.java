package io.github.chw3021.companydefense.dto;

import java.util.List;
import java.util.Map;

public class UserDto {
	private String userId;
	private String userName;
	private int userLevel = 1;
    private Map<String, TowerOwnershipDto> userTowers;  // 타워와 레벨을 매핑
    private Map<String, HobbyOwnershipDto> userHobbies;  // 취미;와 레벨을 매핑
	private List<MailDto> userMails;
	private int userHighScore = 0;
	private int gold = 1000;
	private int time = 5;
	private String idToken;

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
	public Map<String, TowerOwnershipDto> getUserTowers() {
		return userTowers;
	}
	public void setUserTowers(Map<String, TowerOwnershipDto> userTowers) {
		this.userTowers = userTowers;
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
	public int getGold() {
		return gold;
	}
	public void setGold(int gold) {
		this.gold = gold;
	}
	public int getTime() {
		return time;
	}
	public void setTime(int time) {
		this.time = time;
	}
	public String getIdToken() {
		return idToken;
	}
	public void setIdToken(String idToken) {
		this.idToken = idToken;
	}
	public Map<String, HobbyOwnershipDto> getUserHobbies() {
		return userHobbies;
	}
	public void setUserHobbies(Map<String, HobbyOwnershipDto> userHobbies) {
		this.userHobbies = userHobbies;
	}
    
    
}
