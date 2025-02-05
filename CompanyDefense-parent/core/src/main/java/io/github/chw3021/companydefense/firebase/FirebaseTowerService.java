package io.github.chw3021.companydefense.firebase;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Preferences;
import com.google.gson.reflect.TypeToken;

import io.github.chw3021.companydefense.Main;
import io.github.chw3021.companydefense.dto.TowerDto;
import io.github.chw3021.companydefense.dto.TowerOwnershipDto;
import io.github.chw3021.companydefense.dto.UserDto;

public class FirebaseTowerService {
	private static final FirebaseServiceImpl firebaseService = (FirebaseServiceImpl) Main.getInstance().getFirebaseService();

    /**
     * Firebase에서 모든 타워 데이터를 불러옴
     */
    public static void loadAllTowers(FirebaseCallback<List<TowerDto>> callback) {
        firebaseService.fetchData("towers/", new TypeToken<Map<String, TowerDto>>() {}.getType(), new FirebaseCallback<Map<String, TowerDto>>() {
            @Override
            public void onSuccess(Map<String, TowerDto> towersMap) {
                List<TowerDto> towersList = new ArrayList<>(towersMap.values());
                callback.onSuccess(towersList);
            }

            @Override
            public void onFailure(Exception e) {
                callback.onFailure(e);
            }
        });
    }

    /**
     * Firebase에서 사용자 데이터 불러오기 & 기본 타워 저장
     */
    public static void loadUserData(FirebaseCallback<UserDto> callback) {
        Preferences prefs = Gdx.app.getPreferences("GamePreferences");
        String userId = prefs.getString("userId", null);
        if (userId == null) {
            callback.onFailure(new Exception("login required"));
            return;
        }

        firebaseService.fetchData("users/" + userId, UserDto.class, new FirebaseCallback<UserDto>() {
            @Override
            public void onSuccess(UserDto fetchedUser) {
                if (fetchedUser == null || fetchedUser.getUserTowers() == null || fetchedUser.getUserTowers().isEmpty()) {
                    loadAllTowers(new FirebaseCallback<List<TowerDto>>() {
                        @Override
                        public void onSuccess(List<TowerDto> towers) {
                            UserDto newUser = new UserDto();
                            newUser.setUserId(userId);

                            Map<String, TowerOwnershipDto> defaultTowers = new HashMap<>();
                            for (TowerDto tower : towers) {
                                TowerOwnershipDto ownership = new TowerOwnershipDto(tower.getTowerId(), 1);
                                defaultTowers.put(tower.getTowerId(), ownership);

                                // 🔥 TowerOwnership 테이블에도 저장
                                firebaseService.saveData("users/" + userId + "/userTowers/" + tower.getTowerId(), ownership, new FirebaseCallback<Void>() {
                                    @Override
                                    public void onSuccess(Void unused) {
                                        Gdx.app.log("Firebase", "타워 소유권 저장 완료: " + tower.getTowerId());
                                    }

                                    @Override
                                    public void onFailure(Exception e) {
                                        Gdx.app.error("Firebase", "타워 소유권 저장 실패", e);
                                    }
                                });
                            }

                            newUser.setUserTowers(defaultTowers);

                            // 🔥 전체 사용자 데이터 저장
                            firebaseService.saveData("users/" + userId, newUser, new FirebaseCallback<Void>() {
                                @Override
                                public void onSuccess(Void unused) {
                                    callback.onSuccess(newUser);
                                }

                                @Override
                                public void onFailure(Exception e) {
                                    callback.onFailure(e);
                                }
                            });
                        }

                        @Override
                        public void onFailure(Exception e) {
                            callback.onFailure(e);
                        }
                    });
                } else {
                    callback.onSuccess(fetchedUser);
                }
            }

            @Override
            public void onFailure(Exception e) {
                callback.onFailure(e);
            }
        });
    }
    /**
     * 유저의 특정 타워 레벨을 업그레이드하고, 골드를 차감
     */
    public static void upgradeTowerLevel(String userId, String towerId, int newGoldAmount, FirebaseCallback<Void> callback) {
        String towerPath = "users/" + userId + "/userTowers/" + towerId;
        String goldPath = "users/" + userId + "/gold"; // 골드 경로 추가

        firebaseService.fetchData(towerPath, TowerOwnershipDto.class, new FirebaseCallback<TowerOwnershipDto>() {
            @Override
            public void onSuccess(TowerOwnershipDto towerOwnership) {
                if (towerOwnership == null) {
                    callback.onFailure(new Exception("타워 정보 없음"));
                    return;
                }

                // 🔹 타워 레벨 증가 (객체 전체를 업데이트하는 게 아니라 특정 필드만 업데이트)
                int newLevel = towerOwnership.getTowerLevel() + 1;

                // 🔹 Firebase에 타워 레벨과 골드 업데이트
                Map<String, Object> updates = new HashMap<>();
                updates.put(towerPath + "/towerLevel", newLevel); // ⭕ 기존 객체를 덮어씌우지 않고 towerLevel 필드만 업데이트
                updates.put(goldPath, newGoldAmount); // ⭕ 골드 업데이트

                firebaseService.updateData(updates, new FirebaseCallback<Void>() {
                    @Override
                    public void onSuccess(Void unused) {
                        Gdx.app.log("Firebase", "타워 업그레이드 완료: " + towerId + " -> 레벨 " + newLevel + ", 골드: " + newGoldAmount);
                        callback.onSuccess(null);
                    }

                    @Override
                    public void onFailure(Exception e) {
                        Gdx.app.error("Firebase", "타워 업그레이드 실패", e);
                        callback.onFailure(e);
                    }
                });
            }

            @Override
            public void onFailure(Exception e) {
                callback.onFailure(e);
            }
        });
    }

}
