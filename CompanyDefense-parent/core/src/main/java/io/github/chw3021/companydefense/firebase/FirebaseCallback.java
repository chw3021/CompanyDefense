package io.github.chw3021.companydefense.firebase;

public interface FirebaseCallback<T> {
    void onSuccess(T result); // 작업 성공 시 호출
	void onFailure(Exception e);// 작업 실패 시 호출
}
