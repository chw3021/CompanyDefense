package io.github.chw3021.companydefense.android.firebase;

import com.google.firebase.auth.AuthCredential;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.GoogleAuthProvider;
import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;

import java.lang.reflect.Type;
import java.util.Map;

import io.github.chw3021.companydefense.firebase.FirebaseService;
import io.github.chw3021.companydefense.firebase.FirebaseCallback;
import io.github.chw3021.companydefense.firebase.TokenManager;

public class AndroidFirebaseService implements FirebaseService {
    private final FirebaseAuth auth;
    private final FirebaseDatabase database;

    private final TokenManager tokenManager = TokenManager.getInstance();

    public AndroidFirebaseService() {
        auth = FirebaseAuth.getInstance();
        database = FirebaseDatabase.getInstance();
    }

    @Override
    public <T> void fetchData(String path, Class<T> type, FirebaseCallback<T> callback) {
        DatabaseReference ref = database.getReference(path);
        ref.get().addOnSuccessListener(snapshot -> {
            T data = snapshot.getValue(type);
            callback.onSuccess(data);
        }).addOnFailureListener(callback::onFailure);
    }

    @Override
    public <T> void saveData(String path, T data, FirebaseCallback<Void> callback) {
        DatabaseReference ref = database.getReference(path);
        ref.setValue(data).addOnSuccessListener(aVoid -> callback.onSuccess(null))
                .addOnFailureListener(callback::onFailure);
    }

    @Override
    public void login(String email, String password, FirebaseCallback<Void> callback) {
        auth.signInWithEmailAndPassword(email, password)
                .addOnSuccessListener(authResult -> {
                    // idToken 저장 로직 추가
                    authResult.getUser().getIdToken(true)
                            .addOnSuccessListener(result -> {
                                setIdToken(result.getToken());
                                callback.onSuccess(null);
                            })
                            .addOnFailureListener(callback::onFailure);
                })
                .addOnFailureListener(callback::onFailure);
    }

    @Override
    public void loginWithProvider(String provider, String token, FirebaseCallback<Void> callback) {
        AuthCredential credential = null;
        if (provider.equals("google")) {
            credential = GoogleAuthProvider.getCredential(token, null);
        }
        assert credential != null;
        FirebaseAuth.getInstance().signInWithCredential(credential)
            .addOnCompleteListener(task -> {
                if (task.isSuccessful()) {
                    // idToken 저장 로직 추가
                    task.getResult().getUser().getIdToken(true)
                            .addOnSuccessListener(result -> {
                                setIdToken(result.getToken());
                                callback.onSuccess(null);
                            })
                            .addOnFailureListener(callback::onFailure);
                } else {
                    callback.onFailure(task.getException());
                }
            });
    }

    @Override
    public void logout() {
        auth.signOut();
        setIdToken(null);
    }

    @Override
    public String getCurrentUserId() {
        if (auth.getCurrentUser() != null) {
            return auth.getCurrentUser().getUid();
        }
        return null;
    }

    @Override
    public <T> void fetchData(String path, Type type, FirebaseCallback<T> callback) {
        // Type을 사용한 구현 추가
        DatabaseReference ref = database.getReference(path);
        ref.get().addOnSuccessListener(snapshot -> {
            // Android Firebase SDK는 Type을 직접 사용할 수 없으므로
            // 여기서는 Object를 얻어 callback에 전달하는 방식으로 처리
            T data = (T) snapshot.getValue();
            callback.onSuccess(data);
        }).addOnFailureListener(callback::onFailure);
    }

    @Override
    public void updateData(Map<String, Object> updates, FirebaseCallback<Void> callback) {
        // 업데이트 구현 추가
        DatabaseReference ref = database.getReference();
        ref.updateChildren(updates)
                .addOnSuccessListener(aVoid -> callback.onSuccess(null))
                .addOnFailureListener(callback::onFailure);
    }

    @Override
    public void signInAnonymously(FirebaseCallback<String> callback) {
        // 익명 로그인 구현 추가
        auth.signInAnonymously()
                .addOnSuccessListener(authResult -> {
                    authResult.getUser().getIdToken(true)
                            .addOnSuccessListener(result -> {
                                setIdToken(result.getToken());
                                callback.onSuccess(result.getToken());
                            })
                            .addOnFailureListener(callback::onFailure);
                })
                .addOnFailureListener(callback::onFailure);
    }

    @Override
    public void deleteData(String path, FirebaseCallback<Void> callback) {
        // 데이터 삭제 구현 추가
        DatabaseReference ref = database.getReference(path);
        ref.removeValue()
                .addOnSuccessListener(aVoid -> callback.onSuccess(null))
                .addOnFailureListener(callback::onFailure);
    }

    // setIdToken 메서드 추가
    public void setIdToken(String idToken) {
        tokenManager.setIdToken(idToken);
    }
}
