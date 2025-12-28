#!/bin/bash

scpex() {
    local ltmp_args=("$@")  # 将所有参数存储在一个数组中（尽管在这个函数中我们并未直接使用它）
    local ltmp_recursive=false
    local ltmp_port=22      # 默认SSH端口为22
    local ltmp_ source_file=""
    local ltmp_destination=""
    local ltmp_server_user=""
    local ltmp_server_addr=""
    local ltmp_server_path=""
    local ltmp_sshpass_cmd=""
    local ltmp_last_source_file=""  # 用于存储上一个上传的文件路径
    local ltmp_b_dialog_installed=false
    local ltmp_b_zenity_installed=false
    local ltmp_new_source_file=""
    local ltmp_UI_app="dialog"

    # 处理可选参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -r)
                ltmp_recursive=true
                shift
                ;;
            -P)
                shift
                ltmp_port="$1"
                shift
                ;;
            -*)
                echo "scpex: 无效的选项 $1"
                return 1
                ;;
            *)
                # 当遇到非选项参数时，停止解析选项
                break
                ;;
        esac
    done

    # 检查是否提供了足够的参数
    if [[ $# -lt 2 ]]; then
        echo "scpex: 用法: scpex [-r] [-P ltmp_port] ltmp_ source_file_or_dir ltmp_destination"
        return 1
    fi

    # 获取源文件或目录和对端位置
    local ltmp_source_file="$1"
    local ltmp_destination="$2"
    local ltmp_absolute_path=$(readlink -f "$ltmp_source_file")
    #echo "文件的绝对路径: $ltmp_absolute_path"

    # 使用正则表达式匹配 ltmp_destination 字符串，并提取用户、服务器和路径
    if [[ "$ltmp_destination" =~ ([^@]+)@([^:]+):(.*) ]]; then
        ltmp_server_user="${BASH_REMATCH[1]}"  # 第一个捕获组是用户名
        ltmp_server_addr="${BASH_REMATCH[2]}"  # 第二个捕获组是服务器地址
        ltmp_server_path="${BASH_REMATCH[3]}"  # 第三个捕获组是路径
    else
        echo "scpex: 无效的对端服务器地址格式"
        echo "ltmp_destination=$ltmp_destination"
        #return 1
    fi

    # 询问密码（这里可以改为更安全的方式，比如从环境变量或密钥管理服务获取）
    local ltmp_password=""

    if command -v zenity &> /dev/null; then
        echo "zenity 已经安装"
        ltmp_b_zenity_installed=true
        ltmp_UI_app="zenity"
        ltmp_password=$(zenity --password --title "scpex" --text "请输入对端服务器的密码:" 2>/dev/null)
    elif command -v dialog &> /dev/null; then
        echo "dialog 已经安装"
        ltmp_b_dialog_installed=true
        ltmp_UI_app="dialog"
        ltmp_password=$(dialog --passwordbox "请输入对端服务器的密码:" 8 30 2>&1 >/dev/tty)
    else
        echo "zenity 未安装"
        ltmp_b_zenity_installed=false
        ltmp_b_dialog_installed=false
        echo -n "请输入对端服务器的密码: "
        read -s ltmp_password
        echo "$ltmp_password"
    fi
    
    # 构造sshpass命令并执行scp
    ltmp_sshpass_cmd="sshpass -v -e  scp"
    if [[ "$ltmp_recursive" == true ]]; then
        ltmp_sshpass_cmd+=" -r"
    fi
    if [[ "$ltmp_port" != "22" ]]; then
        ltmp_sshpass_cmd+=" -P $ltmp_port"
    fi

    local ltmp_file_size=$(du -sh "$ltmp_source_file" | awk '{print $1}')  # 获取文件大小
    local ltmp_scp_elapsed_time=0  # 初始化耗时为0秒
    local ltmp_scp_elapsed_time_str=""
    local ltmp_start_time=$(date +%s)  # 记录开始时间
    
    # 执行scp命令
    export SSHPASS="$ltmp_password"
    $ltmp_sshpass_cmd "$ltmp_source_file" "$ltmp_destination"
    local ltmp_end_time=$(date +%s)  # 记录结束时间
    if [ $? -eq 0 ]; then
        echo "上传 成功: "
        echo "文件绝对路径: $ltmp_absolute_path"
        echo "参数文件:     $ltmp_source_file"
        echo "目标服务器:   $ltmp_server_addr"
        echo "目标路径:     $ltmp_server_path"
        echo "传输:         $ltmp_file_size"
        ltmp_scp_elapsed_time=$((ltmp_end_time - ltmp_start_time))  # 计算耗时
        if [ $ltmp_scp_elapsed_time == 0 ]; then
            ltmp_scp_elapsed_time_str="小于 1 秒"
        elif [ $ltmp_scp_elapsed_time -lt 60 ]; then
            ltmp_scp_elapsed_time_str="$ltmp_scp_elapsed_time 秒"
        else
            ltmp_scp_elapsed_time_str=$(date -u -d "@$ltmp_scp_elapsed_time" +'%H:%M:%S')
        fi
        echo "耗时:         $ltmp_scp_elapsed_time_str"
    else
        echo "文件上传失败: $ltmp_source_file"
    fi

    export SSHPASS=""
    ltmp_scp_elapsed_time=0
    ltmp_last_source_file="$ltmp_source_file"  # 记录上一个上传的文件路径
   
    # 进入交互式循环
    while true; do
        # 显示使用说明
        cat <<EOF

使用说明:
  输入 r 重新上传上一个文件
  输入 n 上传新文件
  输入 q 退出程序

scpex >
EOF
        # 读取用户输入
        read -r command

        if [[ "$command" == "r" ]]; then
            if [[ -z "$ltmp_last_source_file" ]]; then
                echo "没有上一个文件的信息，请先上传一个文件."
            else
                echo "重新上传文件: $ltmp_last_source_file"
                ltmp_start_time=$(date +%s)  # 记录开始时间
                # 执行scp命令
                export SSHPASS="$ltmp_password"
                $ltmp_sshpass_cmd "$ltmp_last_source_file" "$ltmp_destination"
                ltmp_end_time=$(date +%s)  # 记录结束时间
                if [ $? -eq 0 ]; then
                    echo "再次上传 成功: "
                    echo "文件绝对路径: $ltmp_absolute_path"
                    echo "参数文件:     $ltmp_last_source_file"
                    echo "目标服务器:   $ltmp_server_addr"
                    echo "目标路径:     $ltmp_server_path"
                    echo "传输:         $ltmp_file_size"
                    ltmp_scp_elapsed_time=$((ltmp_end_time - ltmp_start_time))  # 计算耗时
                    if [ $ltmp_scp_elapsed_time == 0 ]; then
                        ltmp_scp_elapsed_time_str="小于 1 秒"
                    elif [ $ltmp_scp_elapsed_time -lt 60 ]; then
                        ltmp_scp_elapsed_time_str="$ltmp_scp_elapsed_time 秒"
                    else
                        ltmp_scp_elapsed_time_str=$(date -u -d "@$ltmp_scp_elapsed_time" +'%H:%M:%S')
                    fi
                    echo "耗时:         $ltmp_scp_elapsed_time_str"
                else
                    echo "文件上传失败: $ltmp_source_file"
                fi
                export SSHPASS=""
                ltmp_scp_elapsed_time=0
            fi
        elif [[ "$command" == "n" ]]; then
            if [ $ltmp_b_zenity_installed = true ];then
                # 使用 zenity 显示文件选择对话框
                file_path=$(zenity --file-selection --title="选择文件" 2>/dev/null)
                # 检查用户是否选择了文件
                if [ $? -eq 0 ]; then
                    echo "Selected file: $file_path"
                    ltmp_new_source_file="$file_path"
                    #???
                else
                    echo "No file selected."
                fi
            elif [ $ltmp_b_dialog_installed = true ];then
                # 使用 dialog 显示文件选择对话框
                file_path=$(dialog --fselect "$HOME/" 14 78 2>&1 >/dev/tty)

                # 检查用户是否选择了文件
                if [ $? -eq 0 ]; then
                    echo "Selected file: $file_path"
                    ltmp_new_source_file="$file_path"
                else
                    echo "No file selected."
                fi
            else
                echo -n "请输入要上传的文件路径: "
                read -r ltmp_new_source_file

            fi
            
            if [[ -f "$ltmp_new_source_file" || -d "$ltmp_new_source_file" ]]; then
                echo "上传文件: $ltmp_new_source_file"
                ltmp_absolute_path=$(readlink -f "$ltmp_new_source_file")

                ltmp_file_size=$(du -sh "$ltmp_new_source_file" | awk '{print $1}')  # 获取文件大小
                ltmp_start_time=$(date +%s)  # 记录开始时间
                export SSHPASS="$ltmp_password"
                $ltmp_sshpass_cmd "$ltmp_new_source_file" "$ltmp_destination"
                ltmp_end_time=$(date +%s)  # 记录结束时间
                if [ $? -eq 0 ]; then
                    echo "上传新文件 成功: "
                    echo "文件绝对路径: $ltmp_absolute_path"
                    echo "参数文件:     $ltmp_new_source_file"
                    echo "目标服务器:   $ltmp_server_addr"
                    echo "目标路径:     $ltmp_server_path"
                    echo "传输:         $ltmp_file_size"
                    ltmp_scp_elapsed_time=$((ltmp_end_time - ltmp_start_time))  # 计算耗时
                    if [ $ltmp_scp_elapsed_time == 0 ]; then
                        ltmp_scp_elapsed_time_str="小于 1 秒"
                    elif [ $ltmp_scp_elapsed_time -lt 60 ]; then
                        ltmp_scp_elapsed_time_str="$ltmp_scp_elapsed_time 秒"
                    else
                        ltmp_scp_elapsed_time_str=$(date -u -d "@$ltmp_scp_elapsed_time" +'%H:%M:%S')
                    fi
                    echo "耗时:         $ltmp_scp_elapsed_time_str"
                else
                    echo "文件上传失败: $ltmp_new_source_file"
                fi
                export SSHPASS=""
                ltmp_scp_elapsed_time=0
                ltmp_last_source_file="$ltmp_new_source_file"  # 更新上一个上传的文件路径
            else
                echo "文件不存在: $ltmp_new_source_file"
            fi
        elif [[ "$command" == "q" ]]; then
            echo "退出程序."
            break
        else
            echo "未知命令: $command"
        fi
    done

    # 清除密码（虽然bash在脚本结束后会自动清除局部变量，但明确清除是个好习惯）
    unset ltmp_sshpass_cmd password
}

scpex "$@"
exit 0
# example:
# scpex -r -P 2222 /path/to/local/dir pangu@192.168.0.17:/home/pangu/test/

# 将上面的函数添加到 .bashrc 或 .bash_profile 文件中，然后重新加载你的shell配置文件
source ~/.bashrc
# 或者
source ~/.bash_profile
