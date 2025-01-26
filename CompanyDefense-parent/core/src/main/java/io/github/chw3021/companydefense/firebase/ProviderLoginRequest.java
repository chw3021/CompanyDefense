package io.github.chw3021.companydefense.firebase;

public class ProviderLoginRequest {
    private final String postBody;
    private final String requestUri = "http://localhost"; // 필수값으로 설정
    private final boolean returnSecureToken = true;

    public ProviderLoginRequest(String providerId, String idToken) {
        this.postBody = "providerId=" + providerId + "&id_token=" + idToken;
    }
}
