package io.github.chw3021.companydefense.firebase;

public class TokenManager {
    private static TokenManager instance;
    private String idToken;
    
    private TokenManager() {}
    
    public static synchronized TokenManager getInstance() {
        if (instance == null) {
            instance = new TokenManager();
        }
        return instance;
    }
    
    public String getIdToken() {
        return idToken;
    }
    
    public void setIdToken(String idToken) {
        this.idToken = idToken;
    }
}
