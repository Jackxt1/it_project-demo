package com.bkkcarglass.backend;

import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

class GenerateAdminHashTest {
    @Test
    void printHash() {
        System.out.println("HASH>>>" + new BCryptPasswordEncoder().encode("Admin1234!") + "<<<HASH");
    }
}
