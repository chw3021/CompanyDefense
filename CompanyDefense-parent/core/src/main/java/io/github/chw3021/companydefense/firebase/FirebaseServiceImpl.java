package io.github.chw3021.companydefense.firebase;

import java.io.IOException;
import java.lang.reflect.Type;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.concurrent.atomic.AtomicInteger;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;

import okhttp3.Call;
import okhttp3.Callback;
import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;

public class FirebaseServiceImpl implements FirebaseService {
    private static final String FIREBASE_DATABASE_URL = "https://company-defense-default-rtdb.firebaseio.com/";
    //private static final String FIREBASE_AUTH_URL = "https://company-defense.firebaseapp.com";
    private static final String API_KEY = "AIzaSyBR1kQXuUPKbRROAN8u-EHDOFcPna0ZM0E"; // Firebase Web API Key

    private final OkHttpClient client = new OkHttpClient();
    protected String currentUserId;

    private List<LoadingListener> loadingListeners = new ArrayList<>();
    private AtomicInteger loadingCounter = new AtomicInteger(0); // 로딩 카운터

    public void addLoadingListener(LoadingListener listener) {
        loadingListeners.add(listener);
    }

    private void notifyLoadingStart() {
        if (loadingCounter.getAndIncrement() == 0) { // 처음 시작될 때만 실행
            for (LoadingListener listener : loadingListeners) {
                listener.onLoadingStart();
            }
        }
    }

    private void notifyLoadingEnd() {
        if (loadingCounter.decrementAndGet() == 0) { // 모든 로딩이 끝나면 실행
            for (LoadingListener listener : loadingListeners) {
                listener.onLoadingEnd();
            }
        }
    }

    // TokenManager 사용
    private final TokenManager tokenManager = TokenManager.getInstance();
    
    

    // idToken 접근 메서드
    public String getIdToken() {
        return tokenManager.getIdToken();
    }
    
    public void setIdToken(String idToken) {
        tokenManager.setIdToken(idToken);
    }
    
    
    @Override
    public <T> void fetchData(String path, Class<T> type, FirebaseCallback<T> callback) {
        notifyLoadingStart();
        String url = FIREBASE_DATABASE_URL + path + ".json?auth=" + getIdToken(); // 🔹 idToken 추가

        Request request = new Request.Builder().url(url).build();
        client.newCall(request).enqueue(new Callback() {
            @Override
            public void onResponse(Call call, Response response) throws IOException {
                try {
                    if (response.isSuccessful()) {
                        String responseBody = response.body().string();
                        T result = new Gson().fromJson(responseBody, type);
                        callback.onSuccess(result);
                    } else {
                        callback.onFailure(new Exception("Request failed: " + response.message()));
                    }
                } finally {
                    notifyLoadingEnd();
                    response.close();
                }
            }

            @Override
            public void onFailure(Call call, IOException e) {
                try {
                    callback.onFailure(e);
                } finally {
                    notifyLoadingEnd();
                }
            }
        });
    }

    
    @Override
    public <T> void fetchData(String path, Type type, FirebaseCallback<T> callback) {
        notifyLoadingStart();
        String url = FIREBASE_DATABASE_URL + path + ".json?auth=" + getIdToken(); // 🔹 idToken 추가
        Request request = new Request.Builder().url(url).build();

        client.newCall(request).enqueue(new Callback() {
            @Override
            public void onResponse(Call call, Response response) throws IOException {
                try {
                    if (response.isSuccessful()) {
                        String responseBody = response.body().string();
                        T result = new Gson().fromJson(responseBody, type); // Type을 사용
                        callback.onSuccess(result);
                    } else {
                        callback.onFailure(new Exception("Request failed: " + response.message()));
                    }
                } finally {
                    notifyLoadingEnd();
                    response.close();
                }
            }

            @Override
            public void onFailure(Call call, IOException e) {
                try {
                    callback.onFailure(e);
                } finally {
                    notifyLoadingEnd();
                }
            }
        });
    }
    
    @Override
    public <T> void saveData(String path, T data, FirebaseCallback<Void> callback) {
        notifyLoadingStart();
        String url = FIREBASE_DATABASE_URL + path + ".json?auth=" + getIdToken(); // 🔹 idToken 추가
        String jsonData = new Gson().toJson(data);

        RequestBody body = RequestBody.create(jsonData, MediaType.get("application/json"));
        Request request = new Request.Builder().url(url).put(body).build();

        client.newCall(request).enqueue(new Callback() {
            @Override
            public void onResponse(Call call, Response response) {
                try {
                    if (response.isSuccessful()) {
                        callback.onSuccess(null);
                    } else {
                        callback.onFailure(new Exception("Request failed: " + response.message()));
                    }
                } finally {
                    notifyLoadingEnd();
                    response.close();
                }
            }

            @Override
            public void onFailure(Call call, IOException e) {
                try {
                    callback.onFailure(e);
                } finally {
                    notifyLoadingEnd();
                }
            }
        });
    }


    @Override
    public void login(String email, String password, FirebaseCallback<Void> callback) {
        notifyLoadingStart();
        String url = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=" + API_KEY;
        String jsonData = new Gson().toJson(new LoginRequest(email, password));

        RequestBody body = RequestBody.create(jsonData, MediaType.get("application/json"));
        Request request = new Request.Builder().url(url).post(body).build();

        client.newCall(request).enqueue(new Callback() {
            @Override
            public void onResponse(Call call, Response response) throws IOException {
                try {
                    if (response.isSuccessful()) {
                        String responseBody = response.body().string();
                        LoginResponse loginResponse = new Gson().fromJson(responseBody, LoginResponse.class);
                        currentUserId = loginResponse.getLocalId(); // 사용자 ID 저장
                        setIdToken(loginResponse.getIdToken()); // 🔹 idToken 저장 추가
                        callback.onSuccess(null);
                    } else {
                        callback.onFailure(new Exception("Login failed: " + response.message()));
                    }
                } finally {
                    notifyLoadingEnd();
                    response.close();
                }
            }

            @Override
            public void onFailure(Call call, IOException e) {
                try {
                    callback.onFailure(e);
                } finally {
                    notifyLoadingEnd();
                }
            }
        });
    }

    @Override
    public void logout() {
        currentUserId = null;
        setIdToken(null); // 🔹 idToken 초기화
    }

    @Override
    public void loginWithProvider(String provider, String token, FirebaseCallback<Void> callback) {
        notifyLoadingStart();
        String url = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=" + API_KEY;

        // 로그인 요청 데이터 생성
        String jsonData = new Gson().toJson(new ProviderLoginRequest(provider, token));
        RequestBody body = RequestBody.create(jsonData, MediaType.get("application/json"));
        Request request = new Request.Builder().url(url).post(body).build();

        client.newCall(request).enqueue(new Callback() {
            @Override
            public void onResponse(Call call, Response response) throws IOException {
                try {
                    if (response.isSuccessful()) {
                        String responseBody = response.body().string();
                        LoginResponse loginResponse = new Gson().fromJson(responseBody, LoginResponse.class);
                        currentUserId = loginResponse.getLocalId(); // 로그인 성공 시 사용자 ID 저장
                        callback.onSuccess(null);
                    } else {
                        callback.onFailure(new Exception("Login with provider failed: " + response.message()));
                    }
                } finally {
                    notifyLoadingEnd();
                    response.close();
                }
            }

            @Override
            public void onFailure(Call call, IOException e) {
                try {
                    callback.onFailure(e);
                } finally {
                    notifyLoadingEnd();
                }
            }
        });
    }


    @Override
    public String getCurrentUserId() {
        return currentUserId; // 현재 사용자 ID 반환
    }
    @Override
    public void updateData(Map<String, Object> updates, FirebaseCallback<Void> callback) {
        notifyLoadingStart();
        String url = FIREBASE_DATABASE_URL + ".json?auth=" + getIdToken(); // Firebase Root 경로

        // 🔹 Null 값 제거 (Firebase에서 Null 값을 허용하지 않기 때문)
        updates.values().removeIf(Objects::isNull);

        if (updates.isEmpty()) {
            callback.onFailure(new Exception("업데이트할 데이터가 없습니다."));
            return;
        }

        String jsonData = new Gson().toJson(updates);
        RequestBody body = RequestBody.create(jsonData, MediaType.get("application/json"));

        Request request = new Request.Builder()
                .url(url)
                .patch(body) // 🔹 여러 값을 업데이트할 때 PATCH 사용
                .build();

        client.newCall(request).enqueue(new Callback() {
            @Override
            public void onResponse(Call call, Response response) {
                try {
                    if (response.isSuccessful()) {
                        callback.onSuccess(null);
                    } else {
                        callback.onFailure(new Exception("업데이트 실패: " + response.message()));
                    }
                } finally {
                    notifyLoadingEnd();
                    response.close();
                }
            }

            @Override
            public void onFailure(Call call, IOException e) {
                try {
                    callback.onFailure(e);
                } finally {
                    notifyLoadingEnd();
                }
            }
        });
    }

    @Override
    public void signInAnonymously(FirebaseCallback<String> callback) {
        notifyLoadingStart();
        String url = "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=" + API_KEY;

        String json = "{ \"returnSecureToken\": true }";
        RequestBody body = RequestBody.create(json, MediaType.get("application/json; charset=utf-8"));

        Request request = new Request.Builder().url(url).post(body).build();
        client.newCall(request).enqueue(new Callback() {
            @Override
            public void onResponse(Call call, Response response) throws IOException {
                try {
                    if (response.isSuccessful()) {
                        String responseBody = response.body().string();
                        JsonObject jsonObject = JsonParser.parseString(responseBody).getAsJsonObject();
                        String idToken = jsonObject.get("idToken").getAsString();
                        callback.onSuccess(idToken);
                    } else {
                        callback.onFailure(new Exception("Anonymous sign-in failed: " + response.message()));
                    }
                } finally {
                    notifyLoadingEnd();
                    response.close();
                }
            }

            @Override
            public void onFailure(Call call, IOException e) {
                try {
                    callback.onFailure(e);
                } finally {
                    notifyLoadingEnd();
                }
            }
        });
    }
    

    @Override
    public void deleteData(String path, FirebaseCallback<Void> callback) {
        notifyLoadingStart();
        String url = FIREBASE_DATABASE_URL + path + ".json?auth=" + getIdToken();
        
        Request request = new Request.Builder()
                .url(url)
                .delete()  // DELETE HTTP 메서드 사용
                .build();
        
        client.newCall(request).enqueue(new Callback() {
            @Override
            public void onResponse(Call call, Response response) {
                try {
                    if (response.isSuccessful()) {
                        callback.onSuccess(null);
                    } else {
                        callback.onFailure(new Exception("삭제 실패: " + response.message()));
                    }
                } finally {
                    notifyLoadingEnd();
                    response.close();
                }
            }
            
            @Override
            public void onFailure(Call call, IOException e) {
                try {
                    callback.onFailure(e);
                } finally {
                    notifyLoadingEnd();
                }
            }
        });
    }

}