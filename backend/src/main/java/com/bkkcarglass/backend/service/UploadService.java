package com.bkkcarglass.backend.service;

import com.cloudinary.Cloudinary;
import com.cloudinary.utils.ObjectUtils;
import com.bkkcarglass.backend.exception.CloudinaryUploadException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class UploadService {

    private final Cloudinary cloudinary;

    public String uploadImage(MultipartFile file) {
        try {
            Map<?, ?> result = cloudinary.uploader().upload(file.getBytes(), ObjectUtils.asMap("resource_type", "image"));
            return (String) result.get("secure_url");
        } catch (IOException e) {
            throw new CloudinaryUploadException("อัปโหลดรูปภาพไม่สำเร็จ กรุณาลองใหม่อีกครั้ง", e);
        }
    }
}
