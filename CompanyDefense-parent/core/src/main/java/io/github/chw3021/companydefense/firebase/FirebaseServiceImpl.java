package io.github.chw3021.companydefense.firebase;

import java.io.IOException;
import java.lang.reflect.Type;
import java.util.ArrayList;
import java.util.List;

import com.badlogic.gdx.Gdx;
import com.google.gson.Gson;

import okhttp3.*;

public class FirebaseServiceImpl implements FirebaseService {
    private static final String FIREBASE_DATABASE_URL = "https://company-defense-default-rtdb.firebaseio.com/";
    //private static final String FIREBASE_AUTH_URL = "https://company-defense.firebaseapp.com";
    private static final String API_KEY = "AIzaSyBR1kQXuUPKbRROAN8u-EHDOFcPna0ZM0E"; // Firebase Web API Key

    private final OkHttpClient client = new OkHttpClient();
	protected String currentUserId;

    private List<LoadingListener> loadingListeners = new ArrayList<>();

    public void addLoadingListener(LoadingListener listener) {
        loadingListeners.add(listener);
    }

    private void notifyLoadingStart() {
        for (LoadingListener listener : loadingListeners) {
            listener.onLoadingStart();
        }
    }

    private void notifyLoadingEnd() {
        for (LoadingListener listener : loadingListeners) {
            listener.onLoadingEnd();
        }
    }
	
	
	
    @Override
    public <T> void fetchData(String path, Class<T> type, FirebaseCallback<T> callback) {
        notifyLoadingStart();
        String url = FIREBASE_DATABASE_URL + path + ".json";
        Request request = new Request.Builder().url(url).build();

        client.newCall(request).enqueue(new Callback() {
            @Override
            public void onResponse(Call call, Response response) throws IOException {
                if (response.isSuccessful()) {
                    String responseBody = response.body().string();
                    T result = new Gson().fromJson(responseBody, type);
                    callback.onSuccess(result);
                } else {
                    callback.onFailure(new Exception("Request failed: " + response.message()));
                }
                notifyLoadingEnd();
            }

            @Override
            public void onFailure(Call call, IOException e) {
                callback.onFailure(e);
                notifyLoadingEnd();
            }
        });
    }
    public <T> void fetchData(String path, Type type, FirebaseCallback<T> callback) {
        notifyLoadingStart();
        String url = FIREBASE_DATABASE_URL + path + ".json";
        Request request = new Request.Builder().url(url).build();

        client.newCall(request).enqueue(new Callback() {
            @Override
            public void onResponse(Call call, Response response) throws IOException {
                if (response.isSuccessful()) {
                    String responseBody = response.body().string();
                    T result = new Gson().fromJson(responseBody, type); // Type을 사용
                    callback.onSuccess(result);
                } else {
                    callback.onFailure(new Exception("Request failed: " + response.message()));
                }
                notifyLoadingEnd();
            }

            @Override
            public void onFailure(Call call, IOException e) {
                callback.onFailure(e);
                notifyLoadingEnd();
            }
        });
    }

    @Override
	public <T> void saveData(String path, T data, FirebaseCallback<Void> callback) {
        notifyLoadingStart();
        String url = FIREBASE_DATABASE_URL + path + ".json";
        String jsonData = new Gson().toJson(data);

        RequestBody body = RequestBody.create(jsonData, MediaType.get("application/json"));
        Request request = new Request.Builder().url(url).put(body).build();

        client.newCall(request).enqueue(new Callback() {
            @Override
            public void onResponse(Call call, Response response) {
                if (response.isSuccessful()) {
                    callback.onSuccess(null);
                } else {
                    callback.onFailure(new Exception("Request failed: " + response.message()));
                }
                notifyLoadingEnd();
            }

            @Override
            public void onFailure(Call call, IOException e) {
                callback.onFailure(e);
                notifyLoadingEnd();
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
                if (response.isSuccessful()) {
                    String responseBody = response.body().string();
                    LoginResponse loginResponse = new Gson().fromJson(responseBody, LoginResponse.class);
                    currentUserId = loginResponse.getLocalId(); // 로그인 성공 시 사용자 ID 저장
                    callback.onSuccess(null);
                } else {
                    callback.onFailure(new Exception("Login failed: " + response.message()));
                }
                notifyLoadingEnd();
            }

            @Override
            public void onFailure(Call call, IOException e) {
                callback.onFailure(e);
                notifyLoadingEnd();
            }
        });
    }

    @Override
    public void logout() {
        currentUserId = null; // 현재 사용자 ID를 초기화
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
                if (response.isSuccessful()) {
                    String responseBody = response.body().string();
                    LoginResponse loginResponse = new Gson().fromJson(responseBody, LoginResponse.class);
                    currentUserId = loginResponse.getLocalId(); // 로그인 성공 시 사용자 ID 저장
                    callback.onSuccess(null);
                } else {
                    callback.onFailure(new Exception("Login with provider failed: " + response.message()));
                }
                notifyLoadingEnd();
            }

            @Override
            public void onFailure(Call call, IOException e) {
                callback.onFailure(e);
                notifyLoadingEnd();
            }
        });
    }

    @Override
    public String getCurrentUserId() {
        return currentUserId; // 현재 사용자 ID 반환
    }

}