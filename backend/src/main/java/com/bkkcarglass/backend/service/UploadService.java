package com.bkkcarglass.backend.service;

import com.cloudinary.Cloudinary;
import com.cloudinary.utils.ObjectUtils;
import com.bkkcarglass.backend.exception.CloudinaryUploadException;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;
import java.util.UUID;

/**
 * Uploads images to Cloudinary when {@code app.cloudinary.cloud-name} is
 * configured. Otherwise falls back to saving the file on local disk (under
 * {@code app.upload.local-dir}, served back at {@code /uploads/**}) so the
 * upload flow still works end-to-end on a machine without Cloudinary
 * credentials (dev/test only — not meant for production).
 */
@Service
@RequiredArgsConstructor
public class UploadService {

    private final Cloudinary cloudinary;

    @Value("${app.cloudinary.cloud-name}")
    private String cloudinaryCloudName;

    @Value("${app.upload.local-dir}")
    private String localDir;

    @Value("${app.upload.public-base-url}")
    private String publicBaseUrl;

    public String uploadImage(MultipartFile file) {
        if (StringUtils.hasText(cloudinaryCloudName)) {
            return uploadToCloudinary(file);
        }
        return saveLocally(file);
    }

    private String uploadToCloudinary(MultipartFile file) {
        try {
            Map<?, ?> result = cloudinary.uploader().upload(file.getBytes(), ObjectUtils.asMap("resource_type", "image"));
            return (String) result.get("secure_url");
        } catch (IOException e) {
            throw new CloudinaryUploadException("อัปโหลดรูปภาพไม่สำเร็จ กรุณาลองใหม่อีกครั้ง", e);
        }
    }

    private String saveLocally(MultipartFile file) {
        try {
            Path dir = Path.of(localDir);
            Files.createDirectories(dir);

            String original = file.getOriginalFilename();
            String extension = (original != null && original.contains("."))
                    ? original.substring(original.lastIndexOf('.'))
                    : "";
            String filename = UUID.randomUUID() + extension;

            Path target = dir.resolve(filename);
            Files.copy(file.getInputStream(), target);

            return publicBaseUrl + "/uploads/" + filename;
        } catch (IOException e) {
            throw new CloudinaryUploadException("อัปโหลดรูปภาพไม่สำเร็จ กรุณาลองใหม่อีกครั้ง", e);
        }
    }
}
