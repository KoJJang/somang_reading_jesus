#!/bin/bash

# ImageMagick을 사용한 이미지 압축 스크립트
# 품질: 70% (시각적 품질 유지하면서 크기 대폭 감소)
# 최대 해상도: 1000px (모바일 화면에 충분)

export PATH="/opt/homebrew/bin:$PATH"

echo "🖼️  ImageMagick 이미지 압축 시작"
echo "================================"

SOURCE_DIR="assets/images/summary"
BACKUP_DIR="${SOURCE_DIR}_original_backup"
QUALITY=70
MAX_SIZE="1000x1000>"

# 백업 생성 여부 확인
echo "📦 원본 백업을 생성하시겠습니까?"
echo "   y: 백업 생성 후 압축"
echo "   n: 바로 압축 (원본 덮어쓰기)"
read -p "선택 (y/n, 기본값 y): " backup_choice

if [[ "$backup_choice" != "n" ]]; then
    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo "📦 백업 생성 중: $BACKUP_DIR"
        cp -r "$SOURCE_DIR" "$BACKUP_DIR"
        echo "✅ 백업 완료"
    else
        echo "⚠️  백업 디렉토리가 이미 존재합니다: $BACKUP_DIR"
    fi
fi

echo ""
echo "🚀 압축 설정:"
echo "   품질: ${QUALITY}%"
echo "   최대 해상도: ${MAX_SIZE}"
echo "   대상 디렉토리: $SOURCE_DIR"
echo ""

# 압축 통계
total_original=0
total_compressed=0
file_count=0
failed_count=0

echo "압축 진행 상황:"
echo "----------------------------------------"

# 모든 이미지 파일 처리
find "$SOURCE_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | while read -r file; do
    # 원본 파일 크기
    original_size=$(stat -f%z "$file" 2>/dev/null || echo "0")
    
    # 임시 파일로 압축
    temp_file="${file}.tmp"
    
    if magick "$file" -quality "$QUALITY" -resize "$MAX_SIZE" "$temp_file" 2>/dev/null; then
        # 압축된 파일 크기
        compressed_size=$(stat -f%z "$temp_file" 2>/dev/null || echo "0")
        
        if [[ $compressed_size -gt 0 ]]; then
            # 원본을 압축된 파일로 교체
            mv "$temp_file" "$file"
            
            # 크기 계산
            reduction=0
            if [[ $original_size -gt 0 ]]; then
                reduction=$(( (original_size - compressed_size) * 100 / original_size ))
            fi
            
            echo "✅ $(basename "$file"): $(( original_size / 1024 ))KB → $(( compressed_size / 1024 ))KB (-${reduction}%)"
            
            total_original=$((total_original + original_size))
            total_compressed=$((total_compressed + compressed_size))
            file_count=$((file_count + 1))
        else
            echo "❌ $(basename "$file"): 압축 실패 (크기 0)"
            rm -f "$temp_file"
            failed_count=$((failed_count + 1))
        fi
    else
        echo "❌ $(basename "$file"): 압축 명령 실패"
        rm -f "$temp_file"
        failed_count=$((failed_count + 1))
    fi
done

# 최종 통계는 서브셸에서 계산되므로 별도로 실행
echo ""
echo "📊 압축 통계 계산 중..."

# 전체 통계 다시 계산
total_original=0
total_compressed=0
file_count=0

find "$SOURCE_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | while read -r file; do
    size=$(stat -f%z "$file" 2>/dev/null || echo "0")
    total_compressed=$((total_compressed + size))
    file_count=$((file_count + 1))
done

# 백업에서 원본 크기 계산 (백업이 있는 경우)
if [[ -d "$BACKUP_DIR" ]]; then
    find "$BACKUP_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | while read -r file; do
        size=$(stat -f%z "$file" 2>/dev/null || echo "0")
        total_original=$((total_original + size))
    done
fi

echo ""
echo "🎉 압축 완료!"
echo "================================"
echo "처리된 파일: $file_count 개"
if [[ -d "$BACKUP_DIR" ]]; then
    echo "백업 위치: $BACKUP_DIR"
fi
echo ""
echo "압축 후 디렉토리 크기:"
du -sh "$SOURCE_DIR"
if [[ -d "$BACKUP_DIR" ]]; then
    echo "원본 백업 크기:"
    du -sh "$BACKUP_DIR"
fi

# 테스트 파일 정리
rm -f test_compressed.jpg

echo ""
echo "✨ 모든 작업이 완료되었습니다!" 