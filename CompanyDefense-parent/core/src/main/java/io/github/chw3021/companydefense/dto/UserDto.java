package io.github.chw3021.companydefense.dto;

import java.util.List;

public class UserDto {
	private String userId;
	private String userName;
	private int userLevel;
	private List<TowerDto> userTowers;
	private List<EquipmentDto> userEquipments;
	private List<MailDto> userMails;
	private int userHighScore;

    // 로그인 서비스 관련 필드
    private String loginProvider; // 예: "google", "ios", "guest", "kakao"
    private String externalId;    // 외부 서비스 ID (Google UID, Kakao UID 등)
}
