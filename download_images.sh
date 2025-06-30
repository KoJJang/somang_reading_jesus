#!/bin/bash

# RJesus Summary 이미지를 로컬에 다운로드하는 스크립트

BASE_URL="https://raw.githubusercontent.com/inspiratives/RJesus/main/Summary"
BASE_DIR="assets/images/summary"

# 각 권별로 다운로드
for volume in {1..6}; do
    # 권별 강수 정의 (실제 GitHub 저장소 구조에 맞게 조정 필요)
    case $volume in
        1) max_chapter=7 ;;
        2) max_chapter=7 ;;
        3) max_chapter=7 ;;
        4) max_chapter=7 ;;
        5) max_chapter=7 ;;
        6) max_chapter=7 ;;
    esac
    
    echo "📁 ${volume}권 이미지 다운로드 중..."
    
    for chapter in $(seq 1 $max_chapter); do
        folder_name="${volume}권%20성경읽기"
        subfolder_name="${volume}권${chapter}강"
        local_dir="${BASE_DIR}/${volume}권${chapter}강"
        
        # 로컬 디렉토리 생성
        mkdir -p "$local_dir"
        
        echo "  📖 ${volume}권 ${chapter}강 처리 중..."
        
        # 각 일차별 이미지 다운로드 (1일부터 12일까지 시도)
        for day in {1..12}; do
            filename="${volume}권${chapter}강_성경읽기_${day}.jpg"
            url="${BASE_URL}/${folder_name}/${subfolder_name}/${filename}"
            local_path="${local_dir}/${filename}"
            
            # 파일이 이미 존재하면 스킵
            if [ -f "$local_path" ]; then
                echo "    ✅ ${filename} (이미 존재)"
                continue
            fi
            
            # 이미지 다운로드
            if curl -s --fail "$url" -o "$local_path"; then
                echo "    ✅ ${filename}"
            else
                echo "    ❌ ${filename} (파일 없음)"
                rm -f "$local_path"  # 실패한 파일 삭제
            fi
        done
    done
done

echo "🎉 이미지 다운로드 완료!"
echo "📊 다운로드된 파일 수: $(find ${BASE_DIR} -name "*.jpg" | wc -l)" 