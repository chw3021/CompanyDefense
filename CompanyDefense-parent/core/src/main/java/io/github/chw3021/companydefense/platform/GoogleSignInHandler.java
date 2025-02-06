package io.github.chw3021.companydefense.platform;

import io.github.chw3021.companydefense.dto.UserDto;
import io.github.chw3021.companydefense.firebase.FirebaseCallback;

public interface GoogleSignInHandler {
    void signIn(FirebaseCallback<UserDto> callback);
}