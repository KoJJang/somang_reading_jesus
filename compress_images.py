#!/usr/bin/env python3
"""
이미지 압축 스크립트
- JPEG 품질을 조정하여 파일 크기 줄이기
- 해상도 조정 (필요시)
- 배치 처리
"""

import os
import sys
from PIL import Image
import shutil

def compress_image(input_path, output_path, quality=75, max_width=1200):
    """
    이미지를 압축합니다.
    
    Args:
        input_path: 원본 이미지 경로
        output_path: 압축된 이미지 저장 경로
        quality: JPEG 품질 (1-100, 기본값 75)
        max_width: 최대 가로 해상도 (기본값 1200px)
    """
    try:
        with Image.open(input_path) as img:
            # RGB로 변환 (JPEG 저장을 위해)
            if img.mode in ('RGBA', 'P'):
                img = img.convert('RGB')
            
            # 해상도 조정 (가로가 max_width보다 큰 경우)
            if img.width > max_width:
                ratio = max_width / img.width
                new_height = int(img.height * ratio)
                img = img.resize((max_width, new_height), Image.Resampling.LANCZOS)
            
            # 압축하여 저장
            img.save(output_path, 'JPEG', quality=quality, optimize=True)
            
            # 파일 크기 비교
            original_size = os.path.getsize(input_path)
            compressed_size = os.path.getsize(output_path)
            reduction = (1 - compressed_size / original_size) * 100
            
            print(f"✅ {os.path.basename(input_path)}: {original_size//1024}KB → {compressed_size//1024}KB ({reduction:.1f}% 감소)")
            return True
            
    except Exception as e:
        print(f"❌ {input_path} 압축 실패: {e}")
        return False

def compress_directory(source_dir, target_dir=None, quality=75, max_width=1200):
    """
    디렉토리 내 모든 이미지를 압축합니다.
    
    Args:
        source_dir: 원본 이미지 디렉토리
        target_dir: 압축된 이미지 저장 디렉토리 (None이면 원본 덮어쓰기)
        quality: JPEG 품질
        max_width: 최대 가로 해상도
    """
    if target_dir and not os.path.exists(target_dir):
        os.makedirs(target_dir)
    
    total_original = 0
    total_compressed = 0
    success_count = 0
    
    for root, dirs, files in os.walk(source_dir):
        for file in files:
            if file.lower().endswith(('.jpg', '.jpeg', '.png')):
                input_path = os.path.join(root, file)
                
                if target_dir:
                    # 새 디렉토리에 저장
                    rel_path = os.path.relpath(input_path, source_dir)
                    output_path = os.path.join(target_dir, rel_path)
                    output_dir = os.path.dirname(output_path)
                    if not os.path.exists(output_dir):
                        os.makedirs(output_dir)
                else:
                    # 임시 파일로 압축 후 원본 덮어쓰기
                    output_path = input_path + ".tmp"
                
                original_size = os.path.getsize(input_path)
                
                if compress_image(input_path, output_path, quality, max_width):
                    compressed_size = os.path.getsize(output_path)
                    
                    if not target_dir:
                        # 원본 덮어쓰기
                        shutil.move(output_path, input_path)
                    
                    total_original += original_size
                    total_compressed += compressed_size
                    success_count += 1
                elif not target_dir and os.path.exists(output_path):
                    # 실패한 경우 임시 파일 삭제
                    os.remove(output_path)
    
    if success_count > 0:
        total_reduction = (1 - total_compressed / total_original) * 100
        print(f"\n📊 압축 완료:")
        print(f"   처리된 파일: {success_count}개")
        print(f"   원본 크기: {total_original // (1024*1024)}MB")
        print(f"   압축 후 크기: {total_compressed // (1024*1024)}MB")
        print(f"   전체 감소율: {total_reduction:.1f}%")
    else:
        print("압축할 이미지를 찾지 못했습니다.")

def main():
    """메인 함수"""
    print("🖼️  이미지 압축 도구")
    print("=" * 50)
    
    # 압축 설정
    source_directory = "assets/images/summary"
    quality = 70  # JPEG 품질 (낮을수록 더 압축)
    max_width = 1000  # 최대 가로 해상도
    
    print(f"📁 소스 디렉토리: {source_directory}")
    print(f"🎚️  JPEG 품질: {quality}")
    print(f"📏 최대 가로 해상도: {max_width}px")
    print()
    
    if not os.path.exists(source_directory):
        print(f"❌ 디렉토리를 찾을 수 없습니다: {source_directory}")
        return
    
    # 백업 생성 여부 확인
    backup_choice = input("🔄 원본 백업을 생성하시겠습니까? (y/n, 기본값 n): ").strip().lower()
    
    if backup_choice in ['y', 'yes']:
        backup_dir = source_directory + "_backup"
        if not os.path.exists(backup_dir):
            print(f"📦 백업 생성 중: {backup_dir}")
            shutil.copytree(source_directory, backup_dir)
            print("✅ 백업 완료")
        else:
            print("⚠️  백업 디렉토리가 이미 존재합니다.")
    
    print("🚀 압축 시작...")
    print()
    
    # 압축 실행 (원본 덮어쓰기)
    compress_directory(source_directory, None, quality, max_width)
    
    print("\n✨ 압축 작업 완료!")

if __name__ == "__main__":
    main() 