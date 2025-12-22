#!/bin/bash

# ビルドスクリプト：開発環境の .env ファイルをアプリバンドルにコピー

set -e

# プロジェクトルートディレクトリの .env ファイルをチェック
# SOURCE_ROOTが設定されていない場合はスクリプトのディレクトリを使用
if [ -z "${SOURCE_ROOT}" ]; then
    PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
else
    PROJECT_ROOT="${SOURCE_ROOT}"
fi
ENV_FILE="${PROJECT_ROOT}/.env"

echo "ビルドスクリプト: .env ファイルをコピー中..."
echo "プロジェクトルート: ${PROJECT_ROOT}"
echo ".env ファイルパス: ${ENV_FILE}"

# .env ファイルが存在するかチェック
if [ -f "${ENV_FILE}" ]; then
    echo ".env ファイルが見つかりました。アプリバンドルにコピー中..."
    
    # Xcode環境変数が設定されている場合（実際のビルド時）
    if [ -n "${BUILT_PRODUCTS_DIR}" ] && [ -n "${PRODUCT_NAME}" ]; then
        APP_BUNDLE="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app"
        DESTINATION="${APP_BUNDLE}/.env"
        
        # アプリバンドルディレクトリが存在することを確認
        if [ -d "${APP_BUNDLE}" ]; then
            cp "${ENV_FILE}" "${DESTINATION}"
            echo ".env ファイルのコピーが完了しました: ${DESTINATION}"
        else
            echo "警告: アプリバンドルディレクトリが見つかりません: ${APP_BUNDLE}"
            echo "ビルドプロセスでバンドルが作成された後に .env をコピーする必要があります"
            # アプリバンドル作成後のフェーズで実行されるようにexit 0で続行
        fi
    else
        # テスト実行時（環境変数なし）
        echo "テスト実行: .env ファイルは正常に見つかりました"
        echo "実際のビルド時にアプリバンドルにコピーされます"
    fi
    
    # セキュリティのため、API キーをマスクして内容を確認
    echo "コピーされた .env ファイルの内容（APIキーはマスク）:"
    sed 's/\(.*API.*=\)\(.*\)/\1[MASKED]/' "${ENV_FILE}"
    
else
    echo "警告: .env ファイルが見つかりません (${ENV_FILE})"
    echo ".env.template を参考に .env ファイルを作成してください。"
    
    # 開発用にはビルドを続行
    exit 0
fi