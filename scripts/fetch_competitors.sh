#!/bin/bash
# 亚马逊竞品数据采集脚本
# 使用 web-access CDP 模式获取商品详情数据

set -e

SKILL_DIR="$HOME/.agents/skills/amazon-competitor-monitor"
WEB_ACCESS_DIR="$HOME/.agents/skills/web-access"

# 检查 CDP Proxy
check_cdp() {
    echo "检查 CDP Proxy..."
    node "$WEB_ACCESS_DIR/scripts/check-deps.mjs" || {
        echo "CDP Proxy 未启动，请先启动"
        exit 1
    }
}

# 获取所有 tab
get_targets() {
    curl -s http://localhost:3456/targets
}

# 创建新 tab
new_tab() {
    local url="$1"
    curl -s "http://localhost:3456/new?url=$url"
}

# 提取商品详情
extract_product_data() {
    local target_id="$1"
    local asin="$2"
    
    curl -s -X POST "http://localhost:3456/eval?target=$target_id" -d '(() => {
        const title = document.querySelector("#productTitle")?.innerText?.trim() || "";
        const price = document.querySelector(".a-price .a-offscreen")?.innerText?.trim() || "";
        const listPrice = document.querySelector(".a-price.a-text-price .a-offscreen")?.innerText?.trim() || "";
        const coupon = document.querySelector("#promoPriceBlockMessage_feature_div, #couponsBadge_feature_div")?.innerText?.trim() || "";
        const rating = document.querySelector("i.a-icon-star span.a-icon-alt")?.innerText?.trim() || "";
        const reviews = document.querySelector("#acrCustomerReviewLink span")?.innerText?.trim() || "";
        const bullets = Array.from(document.querySelectorAll("#featurebullets_feature_div li span.a-list-item")).map(e=>e.innerText.trim()).join("; ");
        const hasPrime = document.querySelector(".a-icon-prime") ? "Yes" : "No";
        return JSON.stringify({asin:"$asin", title, price, listPrice, coupon, rating, reviews, bullets, hasPrime});
    })()'
}

# 从搜索页提取 ASIN
extract_search_asins() {
    local target_id="$1"
    local count="${2:-5}"
    
    curl -s -X POST "http://localhost:3456/eval?target=$target_id" -d '(() => {
        const items = document.querySelectorAll(".s-search-results .s-result-item[data-asin]");
        const results = [];
        for (let i = 0; i < $count && i < items.length; i++) {
            const item = items[i];
            const asin = item.dataset.asin;
            if (!asin || asin === "") continue;
            const title = item.querySelector("h2")?.innerText?.trim() || "";
            const price = item.querySelector(".a-price .a-offscreen")?.innerText?.trim() || "";
            results.push({asin, title, price});
        }
        return JSON.stringify(results);
    })()'
}

# 从 BS 榜单提取 ASIN
extract_bs_asins() {
    local target_id="$1"
    local count="${2:-5}"
    
    curl -s -X POST "http://localhost:3456/eval?target=$target_id" -d '(() => {
        const items = document.querySelectorAll("#gridItemRoot > div");
        const results = [];
        for (let i = 0; i < $count && i < items.length; i++) {
            const item = items[i];
            const title = item.querySelector("a.a-link-normal span div")?.innerText?.trim() || "";
            const link = item.querySelector("a.a-link-normal")?.href || "";
            const asinMatch = link.match(/\/dp\/([A-Z0-9]+)/);
            const asin = asinMatch ? asinMatch[1] : "";
            if (asin) results.push({rank: i+1, asin, title, link});
        }
        return JSON.stringify(results);
    })()'
}

# 关闭 tab
close_tab() {
    local target_id="$1"
    curl -s "http://localhost:3456/close?target=$target_id"
}

# 主流程
main() {
    local url="$1"
    local output_file="$2"
    
    if [ -z "$url" ]; then
        echo "用法: $0 <amazon-url> [output-file]"
        echo "示例: $0 https://www.amazon.co.jp/s?k=デスク data.json"
        exit 1
    fi
    
    output_file="${output_file:-competitors_data.json}"
    
    echo "=== 亚马逊竞品数据采集 ==="
    echo "URL: $url"
    echo "输出: $output_file"
    
    # 1. 检查 CDP
    check_cdp
    
    # 2. 打开页面
    echo "打开页面..."
    local response=$(new_tab "$url")
    local target_id=$(echo "$response" | jq -r '.targetId')
    
    if [ -z "$target_id" ] || [ "$target_id" = "null" ]; then
        echo "无法打开页面"
        exit 1
    fi
    
    sleep 3
    
    # 3. 判断页面类型
    echo "判断页面类型..."
    local page_type=""
    if [[ "$url" =~ "s\?k=" ]]; then
        page_type="search"
    elif [[ "$url" =~ "bestsellers" ]]; then
        page_type="bs"
    elif [[ "$url" =~ "/dp/" ]]; then
        page_type="product"
    fi
    
    # 4. 提取 ASIN
    local asins=""
    case "$page_type" in
        "search")
            echo "提取搜索页ASIN..."
            asins=$(extract_search_asins "$target_id" 5)
            ;;
        "bs")
            echo "提取BS榜单ASIN..."
            asins=$(extract_bs_asins "$target_id" 5)
            ;;
        "product")
            # 直接是商品页
            local asin=$(echo "$url" | grep -oP '/dp/[A-Z0-9]+' | sed 's/\/dp\//')
            asins="[{\"asin\":\"$asin\"}]"
            ;;
        *)
            echo "未知页面类型: $page_type"
            close_tab "$target_id"
            exit 1
            ;;
    esac
    
    echo "ASIN列表: $asins"
    
    # 5. 逐个进入商品详情页采集
    local all_data="[]"
    local asin_array=$(echo "$asins" | jq -c '.[]')
    
    while IFS= read -r item; do
        local asin=$(echo "$item" | jq -r '.asin')
        local product_url="https://www.amazon.co.jp/dp/$asin"
        
        echo "采集商品: $asin"
        
        local prod_response=$(new_tab "$product_url")
        local prod_target=$(echo "$prod_response" | jq -r '.targetId')
        
        sleep 2
        
        local product_data=$(extract_product_data "$prod_target" "$asin")
        all_data=$(echo "$all_data" | jq --argjson item "$product_data" '. + [$item]')
        
        close_tab "$prod_target"
    done <<< "$asin_array"
    
    # 6. 关闭原始页面
    close_tab "$target_id"
    
    # 7. 保存数据
    echo "$all_data" | jq '.' > "$output_file"
    echo "数据已保存至: $output_file"
    
    # 8. 输出摘要
    echo ""
    echo "=== 采集摘要 ==="
    echo "$all_data" | jq -r '.[] | "ASIN: \(.asin) | 价格: \(.price) | 评分: \(.rating) | 评论: \(.reviews)"'
}

main "$@"