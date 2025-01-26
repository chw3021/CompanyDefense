package io.github.chw3021.companydefense.firebase;

public class LoginRequest {
    private String email;
    private String password;
    private boolean returnSecureToken = true;

    public LoginRequest(String email, String password) {
        this.email = email;
        this.password = password;
    }
}