package io.github.chw3021.companydefense.firebase;

public class LoginResponse {
    private String localId; // Firebase에서 사용자 고유 ID
    private String idToken; // 인증 토큰
    private String refreshToken; // 토큰 갱신용
    private String email;

    public String getLocalId() {
        return localId;
    }

    public String getIdToken() {
        return idToken;
    }

    public String getRefreshToken() {
        return refreshToken;
    }

    public String getEmail() {
        return email;
    }
}
