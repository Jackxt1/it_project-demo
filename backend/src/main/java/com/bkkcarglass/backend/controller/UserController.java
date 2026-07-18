package com.bkkcarglass.backend.controller;

import com.bkkcarglass.backend.dto.FcmTokenUpdateRequest;
import com.bkkcarglass.backend.service.UserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

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
}
