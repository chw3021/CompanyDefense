package io.github.chw3021.companydefense.screens;

import io.github.chw3021.companydefense.dto.UserDto;
import io.github.chw3021.companydefense.firebase.FirebaseCallback;

public interface PlatformInterface {
    void signInWithGoogle(FirebaseCallback<UserDto> callback);
}
