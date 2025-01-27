package io.github.chw3021.companydefense.firebase;

import java.lang.reflect.Type;

public interface FirebaseService {
    // Firebase 데이터베이스에서 데이터를 읽어오기
    <T> void fetchData(String path, Class<T> type, FirebaseCallback<T> callback);

    // Firebase 데이터베이스에 데이터 저장
    <T> void saveData(String path, T data, FirebaseCallback<Void> callback);

    // Firebase Authentication: 사용자 로그인
    void login(String email, String password, FirebaseCallback<Void> callback);

    // Firebase Authentication: 사용자 로그아웃
    void logout();

    // 외부 로그인 (Google, Kakao 등)
    void loginWithProvider(String provider, String token, FirebaseCallback<Void> callback);
    
    
    // Firebase Authentication: 현재 로그인된 사용자 정보 가져오기
    String getCurrentUserId();

	<T> void fetchData(String path, Type type, FirebaseCallback<T> callback);
    

}
