package com.bkkcarglass.backend.controller;

import com.bkkcarglass.backend.dto.ChangePasswordRequest;
import com.bkkcarglass.backend.dto.FcmTokenUpdateRequest;
import com.bkkcarglass.backend.dto.UpdateProfileRequest;
import com.bkkcarglass.backend.dto.UserResponse;
import com.bkkcarglass.backend.service.UserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @PostMapping("/fcm-token")
    public ResponseEntity<Void> updateFcmToken(@Valid @RequestBody FcmTokenUpdateRequest request) {
        userService.updateFcmToken(request.getFcmToken());
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/me")
    public ResponseEntity<UserResponse> me() {
        return ResponseEntity.ok(userService.getMyProfile());
    }

    @PutMapping("/me")
    public ResponseEntity<UserResponse> updateProfile(@Valid @RequestBody UpdateProfileRequest request) {
        return ResponseEntity.ok(userService.updateProfile(request));
    }

    @PutMapping("/me/password")
    public ResponseEntity<Void> changePassword(@Valid @RequestBody ChangePasswordRequest request) {
        userService.changePassword(request);
        return ResponseEntity.noContent().build();
    }
}
