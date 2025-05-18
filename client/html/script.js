// script.js - 任务系统前端逻辑

// 全局变量
let allMissions = {}; // 存储所有任务数据
let currentCategory = null; // 当前选中的任务分类
let filteredMissions = []; // 筛选后的任务列表
let debounceTimeout = null; // 防抖计时器

// 初始化函数
document.addEventListener('DOMContentLoaded', () => {
    // 注册事件监听器
    setupEventListeners();

    // 开发模式下模拟数据（仅在开发环境使用）
    if (window.location.href.includes('localhost') || window.location.href.includes('127.0.0.1')) {
        simulateServerData();
    }
});

// 设置所有事件监听器
function setupEventListeners() {
    // 关闭任务界面按钮
    document.querySelector('.close-modal').addEventListener('click', closeModal);

    // 开始任务按钮
    document.getElementById('startMissionBtn').addEventListener('click', handleStartMission);

    // 筛选和搜索相关事件监听器
    setupFilterListeners();

    // 为ESC键添加关闭界面事件
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            // 先检查任务详情模态框是否打开，如果打开则先关闭模态框
            const modal = document.getElementById('missionModal');
            if (modal && modal.style.display === 'block') {
                closeModal();
                return; // 阻止事件继续传播，不关闭整个任务系统界面
            }
            // 如果任务详情未打开，则关闭整个任务系统界面
            $.post('https://esx_missions/closeMissions', JSON.stringify({}));
        }
    });
}

// 防抖函数封装 - 减少频繁调用
function debounce(func, delay = 300) {
    return function(...args) {
        clearTimeout(debounceTimeout);
        debounceTimeout = setTimeout(() => {
            func.apply(this, args);
        }, delay);
    };
}

// 设置筛选和搜索相关的监听器
function setupFilterListeners() {
    // 使用防抖函数优化搜索和筛选操作
    const debouncedApplyFilters = debounce(applyFilters);

    // 奖励类型筛选
    document.querySelectorAll('.reward-filter-checkbox').forEach(checkbox => {
        checkbox.addEventListener('change', debouncedApplyFilters);
    });

    // 任务状态筛选
    document.getElementById('statusFilterSelect').addEventListener('change', debouncedApplyFilters);

    // 排序方式
    document.getElementById('sortSelect').addEventListener('change', debouncedApplyFilters);

    // 搜索框 - 使用输入防抖
    document.getElementById('searchInput').addEventListener('input', debouncedApplyFilters);
}

// 监听来自服务器的消息
window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.type === 'setMissionUI') {
        if (data.status) {
            // 显示任务界面并加载数据
            document.querySelector('.app-container').style.display = 'flex';

            // 如果提供了任务数据, 则加载
            if (data.missions) {
                allMissions = data.missions;

                // 保存玩家任务进度数据
                if (data.playerMissions) {
                    // 遍历任务配置, 将玩家任务进度数据合并到配置中
                    for (const categoryName in allMissions) {
                        const categoryConfig = allMissions[categoryName];
                        const playerCategoryData = data.playerMissions[categoryName] || [];

                        if (categoryConfig.mission && Array.isArray(categoryConfig.mission)) {
                            // 为每个任务添加进度和完成状态
                            categoryConfig.mission.forEach(mission => {
                                // 查找玩家对应任务的进度数据
                                const playerMissionData = playerCategoryData.find(m => m.name === mission.name);

                                if (playerMissionData) {
                                    // 合并玩家任务数据到配置中
                                    mission.completed = playerMissionData.completed || false;
                                    mission.completed_count = playerMissionData.progress || 0;
                                    mission.lastReset = playerMissionData.lastReset || 0;
                                } else {
                                    // 没有玩家数据, 设置默认值
                                    mission.completed = false;
                                    mission.completed_count = 0;
                                    mission.lastReset = 0;
                                }
                            });
                        }
                    }
                }

                loadMissionCategories();

                // 根据_index排序获取第一个分类
                const sortedCategories = Object.entries(allMissions).sort((a, b) =>
                    a[1]._index - b[1]._index
                );

                if (sortedCategories.length > 0) {
                    // 选择排序后的第一个分类
                    selectCategory(sortedCategories[0][0]);
                }
            }
        } else {
            // 隐藏任务界面
            document.querySelector('.app-container').style.display = 'none';
        }
    } else if (data.type === 'updateMissions') {
        // 处理任务更新事件
        if (data.playerMissions) {
            // 遍历任务配置, 更新玩家任务进度数据
            for (const categoryName in allMissions) {
                const categoryConfig = allMissions[categoryName];
                const playerCategoryData = data.playerMissions[categoryName] || [];

                if (categoryConfig.mission && Array.isArray(categoryConfig.mission)) {
                    // 为每个任务更新进度和完成状态
                    categoryConfig.mission.forEach(mission => {
                        // 查找玩家对应任务的进度数据
                        const playerMissionData = playerCategoryData.find(m => m.name === mission.name);

                        if (playerMissionData) {
                            // 更新任务数据
                            mission.completed = playerMissionData.completed || false;
                            mission.completed_count = playerMissionData.progress || 0;
                            mission.lastReset = playerMissionData.lastReset || 0;
                        }
                    });
                }
            }

            // 如果有当前选中的分类, 重新加载任务列表以更新UI
            if (currentCategory) {
                loadMissions(currentCategory);
            }
        }
    }
});

// 加载任务分类到侧边栏 - 优化为一次性DOM操作
function loadMissionCategories() {
    const missionTabs = document.getElementById('missionTabs');

    // 创建文档片段, 减少DOM重绘次数
    const fragment = document.createDocumentFragment();

    // 根据_index属性排序分类
    const sortedCategories = Object.entries(allMissions).sort((a, b) =>
        a[1]._index - b[1]._index
    );

    sortedCategories.forEach(([category, data]) => {
        // 计算该分类下的未完成任务数量
        let pendingCount = 0;
        if (data.mission && Array.isArray(data.mission)) {
            pendingCount = data.mission.filter(mission => !mission.completed).length;
        }

        const tab = document.createElement('button');
        tab.className = 'mission-tab';
        tab.dataset.category = category;

        let tabContent = `
            <i class="fas fa-${data.icon}"></i>
            <span>${data.title}</span>
        `;

        // 如果有待完成任务, 添加计数标签
        if (pendingCount > 0) {
            tabContent += `<span class="task-count">${pendingCount}</span>`;
        }

        tab.innerHTML = tabContent;
        tab.addEventListener('click', () => selectCategory(category));
        fragment.appendChild(tab);
    });

    // 清空现有内容并一次性添加所有元素
    missionTabs.innerHTML = '';
    missionTabs.appendChild(fragment);
}

// 选择任务分类
function selectCategory(category) {
    // 更新当前选中分类
    currentCategory = category;

    // 更新UI - 使用classList方法而不是直接操作className
    document.querySelectorAll('.mission-tab').forEach(tab => {
        tab.classList.toggle('active', tab.dataset.category === category);
    });

    // 显示该分类下的任务
    loadMissions(category);
}

// 加载指定分类的任务列表
function loadMissions(category) {
    if (!allMissions[category] || !allMissions[category].mission) {
        return;
    }

    // 储存当前分类下的所有任务
    filteredMissions = [...allMissions[category].mission];

    // 应用过滤器
    applyFilters();
}

// 应用过滤和搜索, 并更新任务列表
function applyFilters() {
    if (!currentCategory || !allMissions[currentCategory]) return;

    let missions = [...allMissions[currentCategory].mission];

    // 1. 应用奖励类型筛选
    const rewardFilters = getSelectedRewardFilters();
    if (!rewardFilters.includes('all')) {
        missions = missions.filter(mission => {
            if (!mission.reward) return false;

            // 检查任务是否包含任一选中的奖励类型
            return rewardFilters.some(filter => {
                switch(filter) {
                    case 'xp':
                        return mission.reward.xp && mission.reward.xp > 0;
                    case 'money':
                        return mission.reward.money && mission.reward.money > 0;
                    case 'item':
                        return mission.reward.item && Array.isArray(mission.reward.item) && mission.reward.item.length > 0;
                    case 'car':
                        return mission.reward.car && Array.isArray(mission.reward.car) && mission.reward.car.length > 0;
                    default:
                        return false;
                }
            });
        });
    }

    // 2. 应用任务状态筛选
    const statusFilter = document.getElementById('statusFilterSelect').value;
    if (statusFilter !== 'all_status') {
        missions = missions.filter(mission => {
            // 这里需要根据实际存储状态的方式来调整
            const isCompleted = mission.completed === true;
            return statusFilter === 'completed' ? isCompleted : !isCompleted;
        });
    }

    // 3. 应用搜索
    const searchQuery = document.getElementById('searchInput').value.toLowerCase().trim();
    if (searchQuery) {
        missions = missions.filter(mission =>
            mission.title.toLowerCase().includes(searchQuery) ||
            mission.description.toLowerCase().includes(searchQuery)
        );
    }

    // 4. 应用排序
    const sortOption = document.getElementById('sortSelect').value;
    missions = sortMissions(missions, sortOption);

    // 更新任务列表显示
    renderMissionList(missions);

    // 更新全局过滤后的任务列表
    filteredMissions = missions;
}

// 获取选中的奖励类型过滤器
function getSelectedRewardFilters() {
    // 使用Array.from优化NodeList转换
    const checkboxes = Array.from(document.querySelectorAll('.reward-filter-checkbox:checked'));

    // 检查全选按钮
    if (checkboxes.some(cb => cb.dataset.filterValue === 'all')) {
        return ['all']; // 如果全选按钮被选中, 直接返回
    }

    // 获取所有选中的具体筛选条件
    const selectedFilters = checkboxes.map(cb => cb.dataset.filterValue);

    // 如果没有任何选中项, 默认返回全部
    return selectedFilters.length === 0 ? ['all'] : selectedFilters;
}

// 根据选项对任务排序 - 使用更高效的排序
function sortMissions(missions, sortOption) {
    return [...missions].sort((a, b) => {
        // 优化获取排序值的逻辑, 减少条件判断
        const getRewardValue = (mission, type) => {
            return mission.reward && mission.reward[type] ? mission.reward[type] : 0;
        };

        switch (sortOption) {
            case 'xp_desc':
                return getRewardValue(b, 'xp') - getRewardValue(a, 'xp');
            case 'xp_asc':
                return getRewardValue(a, 'xp') - getRewardValue(b, 'xp');
            case 'money_desc':
                return getRewardValue(b, 'money') - getRewardValue(a, 'money');
            case 'money_asc':
                return getRewardValue(a, 'money') - getRewardValue(b, 'money');
            case 'name_asc':
                return a.title.localeCompare(b.title);
            case 'name_desc':
                return b.title.localeCompare(a.title);
            default:
                return 0; // 默认排序, 保持原顺序
        }
    });
}

// 构建任务奖励HTML字符串的辅助函数 - 抽取公共代码减少重复
function buildRewardHTML(reward) {
    if (!reward) return '';

    let rewardHTML = '';

    if (reward.xp) {
        rewardHTML += `<div class="reward-item"><i class="fas fa-star"></i> ${reward.xp} 经验</div>`;
    }

    if (reward.money) {
        rewardHTML += `<div class="reward-item"><i class="fas fa-dollar-sign"></i> ${reward.money} 金钱</div>`;
    }

    if (reward.item && reward.item.length > 0) {
        reward.item.forEach(item => {
            rewardHTML += `<div class="reward-item"><i class="fas fa-box"></i> ${item.label} x${item.amount}</div>`;
        });
    }

    if (reward.car && reward.car.length > 0) {
        reward.car.forEach(car => {
            rewardHTML += `<div class="reward-item"><i class="fas fa-car"></i> ${car.label} x${car.amount}</div>`;
        });
    }

    return rewardHTML;
}

// 构建任务进度HTML
function buildProgressHTML(mission) {
    if (!mission.count || mission.count <= 1) return '';

    const percentage = ((mission.completed_count || 0) / mission.count * 100);

    return `
        <div class="progress">
            <div class="progress-bar" role="progressbar" style="width: ${percentage}%"></div>
        </div>
        <div class="text-end text-secondary small">${mission.completed_count || 0}/${mission.count}</div>
    `;
}

// 渲染任务列表 - 使用文档片段优化DOM操作
function renderMissionList(missions) {
    const missionList = document.getElementById('missionList');

    // 使用文档片段减少DOM重绘
    const fragment = document.createDocumentFragment();

    if (missions.length === 0) {
        const noMissions = document.createElement('div');
        noMissions.className = 'no-missions';
        noMissions.textContent = '没有找到符合条件的任务';
        fragment.appendChild(noMissions);
    } else {
        missions.forEach(mission => {
            const missionCard = document.createElement('div');
            missionCard.className = 'mission-card';
            missionCard.dataset.name = mission.name;

            // 标题行容器
            const titleRow = document.createElement('div');
            titleRow.className = 'mission-title-row';

            // 图标
            const iconElem = document.createElement('i');
            iconElem.className = `fas fa-${mission.icon} mission-icon`;

            // 标题
            const titleElem = document.createElement('span');
            titleElem.className = 'mission-title';
            titleElem.textContent = mission.title;

            // 展开/收起按钮
            const toggleBtn = document.createElement('button');
            toggleBtn.className = 'mission-toggle-btn';
            toggleBtn.innerHTML = '<i class="fas fa-chevron-right"></i>';
            toggleBtn.title = '展开/收起';

            // 组装标题行
            titleRow.appendChild(iconElem);
            titleRow.appendChild(titleElem);
            titleRow.appendChild(toggleBtn);
            missionCard.appendChild(titleRow);

            // 使用抽取的辅助函数生成HTML
            const rewardHTML = buildRewardHTML(mission.reward);
            const progressHTML = buildProgressHTML(mission);

            // 重置类型信息
            let resetTypeHTML = '';
            if (mission.resetTypeText) {
                resetTypeHTML = `<p><i class="fas fa-sync-alt"></i> ${mission.resetTypeText}</p>`;
            }

            // 卡片可折叠内容
            const collapsibleContent = document.createElement('div');
            collapsibleContent.className = 'mission-card-collapsible';
            collapsibleContent.innerHTML = `
                <div class="mission-description">${mission.description}</div>
                ${progressHTML}
                <div class="mission-reward">
                    <h5>任务奖励</h5>
                    <div class="reward-items">
                        ${rewardHTML}
                    </div>
                </div>
                <div class="mt-3">
                    <p><i class="fas fa-info-circle"></i> 任务需要完成 ${mission.count} 次</p>
                    ${mission.levelRequire > 0 ? `<p><i class="fas fa-level-up-alt"></i> 需要等级: ${mission.levelRequire}</p>` : ''}
                    ${resetTypeHTML}
                </div>
                <div class="d-flex justify-content-end mt-2">
                    <button class="btn btn-primary btn-sm mission-detail-btn">详情</button>
                </div>
            `;
            missionCard.appendChild(collapsibleContent);

            // 仅给关键元素添加事件, 避免事件委托重复
            toggleBtn.addEventListener('click', (e) => {
                e.stopPropagation();
                missionCard.classList.toggle('open');
                toggleBtn.classList.toggle('open');
            });

            // 使用事件委托方式绑定详情按钮点击
            const detailBtn = collapsibleContent.querySelector('.mission-detail-btn');
            if (detailBtn) {
                detailBtn.addEventListener('click', (e) => {
                    e.stopPropagation();
                    showMissionDetails(mission);
                });
            }

            // 添加任务完成状态
            if (mission.completed) {
                missionCard.classList.add('completed');
            }

            fragment.appendChild(missionCard);
        });
    }

    // 清空并一次性添加所有内容
    missionList.innerHTML = '';
    missionList.appendChild(fragment);
}

// 显示任务详情
function showMissionDetails(mission) {
    const modal = document.getElementById('missionModal');
    const modalDetailsDiv = document.querySelector('.mission-details');

    // 格式化最后重置时间
    let lastResetText = "";
    if (mission.resetType && mission.resetType !== 'never') {
        if (mission.lastReset && mission.lastReset > 0) {
            const resetDate = new Date(mission.lastReset * 1000);
            lastResetText = `<div class="last-reset-time"><i class="fas fa-history"></i> 上次重置: ${resetDate.toLocaleString()}</div>`;
        }
    }

    // 计算进度百分比
    const progressPercent = Math.min(((mission.completed_count || 0) / (mission.count || 1)) * 100, 100);

    // 任务状态标签
    const statusLabel = mission.completed ?
        '<span class="status-badge completed"><i class="fas fa-check-circle"></i> 已完成</span>' :
        '<span class="status-badge incomplete"><i class="fas fa-clock"></i> 进行中</span>';

    modalDetailsDiv.innerHTML = `
        <div class="mission-detail-header">
            <div class="mission-icon-wrapper">
                <i class="fas fa-${mission.icon}"></i>
            </div>
            <div class="mission-header-content">
                <h3 class="mission-title">${mission.title}</h3>
                ${statusLabel}
            </div>
        </div>

        <div class="mission-detail-body">
            <div class="mission-description-box">
                <p>${mission.description}</p>
            </div>

            <div class="mission-info-grid">
                <div class="info-card">
                    <div class="info-card-header">
                        <i class="fas fa-tasks"></i>
                        <span>任务进度</span>
                    </div>
                    <div class="info-card-content">
                        <div class="progress-wrapper">
                            <div class="progress-label">${mission.completed_count || 0}/${mission.count || 1}</div>
                            <div class="progress">
                                <div class="progress-bar" style="width: ${progressPercent}%"></div>
                            </div>
                            <div class="progress-percent">${Math.round(progressPercent)}%</div>
                        </div>
                    </div>
                </div>

                <div class="info-card">
                    <div class="info-card-header">
                        <i class="fas fa-info-circle"></i>
                        <span>任务信息</span>
                    </div>
                    <div class="info-card-content">
                        <div class="info-item">
                            <i class="fas fa-level-up-alt"></i>
                            <span>等级要求：</span>
                            <strong>${mission.levelRequire || 0}</strong>
                        </div>
                        <div class="info-item">
                            <i class="fas fa-bullseye"></i>
                            <span>目标次数：</span>
                            <strong>${mission.count || 1}</strong>
                        </div>
                        ${mission.resetTypeText ? `
                        <div class="info-item">
                            <i class="fas fa-sync-alt"></i>
                            <span>重置类型：</span>
                            <strong class="reset-type-value">${mission.resetTypeText}</strong>
                        </div>` : ''}
                        ${lastResetText ? `
                        <div class="info-item">
                            ${lastResetText}
                        </div>` : ''}
                    </div>
                </div>

                <div class="info-card reward-card">
                    <div class="info-card-header">
                        <i class="fas fa-gift"></i>
                        <span>任务奖励</span>
                    </div>
                    <div class="info-card-content rewards-container">
                        ${buildRewardHTMLForDetail(mission.reward)}
                    </div>
                </div>
            </div>
        </div>
    `;

    // 设置开始任务按钮的状态
    const startBtn = document.getElementById('startMissionBtn');
    startBtn.dataset.missionName = mission.name;
    startBtn.dataset.category = currentCategory;
    startBtn.dataset.help = mission.help || '';

    // 根据任务完成状态设置按钮文字和样式
    if (mission.completed) {
        startBtn.textContent = '已完成';
        startBtn.classList.add('btn-success');
        startBtn.classList.remove('btn-primary');
        startBtn.disabled = true;
    } else {
        startBtn.textContent = '开始任务';
        startBtn.classList.add('btn-primary');
        startBtn.classList.remove('btn-success');
        startBtn.disabled = false;
    }

    // 显示弹窗并添加动画类
    modal.style.display = 'block';
    // 使用setTimeout确保display:block生效后再添加动画类
    setTimeout(() => {
        modal.classList.add('show');
    }, 10);
}

// 专门为详情页构建奖励HTML
function buildRewardHTMLForDetail(reward) {
    if (!reward) return '<div class="no-rewards">无奖励信息</div>';

    let rewardHTML = '';

    if (reward.xp) {
        rewardHTML += `
            <div class="reward-detail-item xp">
                <div class="reward-icon"><i class="fas fa-star"></i></div>
                <div class="reward-info">
                    <span class="reward-value">${reward.xp}</span>
                    <span class="reward-label">经验</span>
                </div>
            </div>`;
    }

    if (reward.money) {
        rewardHTML += `
            <div class="reward-detail-item money">
                <div class="reward-icon"><i class="fas fa-dollar-sign"></i></div>
                <div class="reward-info">
                    <span class="reward-value">${reward.money}</span>
                    <span class="reward-label">金钱</span>
                </div>
            </div>`;
    }

    if (reward.item && reward.item.length > 0) {
        reward.item.forEach(item => {
            rewardHTML += `
                <div class="reward-detail-item item">
                    <div class="reward-icon"><i class="fas fa-box"></i></div>
                    <div class="reward-info">
                        <span class="reward-value">${item.label} x${item.amount}</span>
                        <span class="reward-label">物品</span>
                    </div>
                </div>`;
        });
    }

    if (reward.car && reward.car.length > 0) {
        reward.car.forEach(car => {
            rewardHTML += `
                <div class="reward-detail-item car">
                    <div class="reward-icon"><i class="fas fa-car"></i></div>
                    <div class="reward-info">
                        <span class="reward-value">${car.label} x${car.amount}</span>
                        <span class="reward-label">车辆</span>
                    </div>
                </div>`;
        });
    }

    return rewardHTML || '<div class="no-rewards">无奖励信息</div>';
}

// 关闭任务详情模态框
function closeModal() {
    const modal = document.getElementById('missionModal');
    // 移除动画类
    modal.classList.remove('show');
    // 等待动画完成后隐藏模态框
    setTimeout(() => {
        modal.style.display = 'none';
    }, 300);
}

// 处理开始任务操作
function handleStartMission() {
    const missionName = document.getElementById('startMissionBtn').dataset.missionName;
    if (!missionName || !currentCategory) return;

    // 查找该任务的详细信息 - 使用数组方法优化查找
    const mission = filteredMissions.find(m => m.name === missionName);
    if (!mission) return;

    // 关闭模态框
    closeModal();

    // 向服务器发送开始任务请求
    $.post('https://esx_missions/startMission', JSON.stringify({
        missionName: mission.name,
        category: currentCategory,
        help: mission.help
    }));
}

// 更新奖励类型筛选按钮文本 - 优化DOM操作和条件判断
function updateRewardFilterDropdownText() {
    const btn = document.getElementById('rewardFilterDropdown');
    if (!btn) return;

    const allCheckbox = document.querySelector('.reward-filter-checkbox[data-filter-value="all"]');

    // 如果全选
    if (allCheckbox && allCheckbox.checked) {
        btn.textContent = '全部类型';
        return;
    }

    // 获取所有勾选的类型 - 使用数组方法优化
    const checkedBoxes = Array.from(
        document.querySelectorAll('.reward-filter-checkbox:not([data-filter-value="all"]):checked')
    );

    if (checkedBoxes.length === 0) {
        btn.textContent = '选择奖励';
        return;
    }

    // 创建映射对象减少条件判断
    const labelMap = {
        xp: '经验',
        money: '金钱',
        item: '物品',
        car: '车辆'
    };

    // 使用映射和数组方法优化文本生成
    const text = checkedBoxes
        .map(cb => labelMap[cb.dataset.filterValue] || cb.dataset.filterValue)
        .join(', ');

    btn.textContent = text;
}

// 初始化奖励筛选复选框事件
document.addEventListener('DOMContentLoaded', () => {
    const allCheckbox = document.querySelector('.reward-filter-checkbox[data-filter-value="all"]');
    const otherCheckboxes = document.querySelectorAll('.reward-filter-checkbox:not([data-filter-value="all"])');

    if (!allCheckbox) return;

    // 初始状态设置
    if (allCheckbox.checked) {
        otherCheckboxes.forEach(cb => {
            cb.checked = false;
        });
    }

    updateRewardFilterDropdownText(); // 初始化文本

    // 使用事件委托优化复选框事件处理 - 减少事件监听器数量
    document.addEventListener('change', (e) => {
        const target = e.target;
        if (!target.classList.contains('reward-filter-checkbox')) return;

        if (target.dataset.filterValue === 'all') {
            // 全选按钮点击
            if (target.checked) {
                otherCheckboxes.forEach(cb => {
                    cb.checked = false;
                });
            }
        } else {
            // 其他按钮点击
            if (target.checked) {
                allCheckbox.checked = false;
            } else {
                // 检查是否没有其他选项被选中
                const anyChecked = Array.from(otherCheckboxes).some(cb => cb.checked);
                if (!anyChecked) {
                    allCheckbox.checked = true;
                }
            }
        }

        updateRewardFilterDropdownText();
        applyFilters();
    });
});

// 开发环境中模拟服务器数据的函数
function simulateServerData() {
    // 从config.lua导入的示例数据
    const mockMissions = {
        '新手任务': {
            _index: 1,
            icon: 'grip-lines',
            title: '新手任务',
            description: '完成新手任务, 获得丰厚新手奖励',
            mission: [
                {
                    icon: 'car',
                    name: 'get_noob_car',
                    title: '获得一辆新手车',
                    description: '获得一辆新手车',
                    help: 'get_noob_car_help',
                    count: 1,
                    levelRequire: 0,
                    reward: {
                        xp: 100,
                        money: 1000,
                        item: [
                            {
                                name: 'water',
                                label: '瓶装水',
                                amount: 1,
                            }
                        ],
                        car: [
                            {
                                name: 'pcj',
                                label: 'PCJ 600',
                                amount: 1,
                            }
                        ]
                    }
                },
                {
                    icon: 'calendar-check',
                    name: 'do_daily_signin',
                    title: '每日签到',
                    description: '每日登录服务器即可在F5签到, 获得丰厚奖励',
                    help: '每日登录服务器即可在F5签到, 获得丰厚奖励',
                    count: 1,
                    levelRequire: 0,
                    reward: {
                        xp: 100,
                        money: 1000,
                        item: [
                            {
                                name: 'water',
                                label: '瓶装水',
                                amount: 1,
                            }
                        ]
                    }
                }
            ]
        },
        '日常任务': {
            _index: 4,
            icon: 'cloud-sun',
            title: '日常任务',
            description: '完成日常任务, 获得丰厚日常奖励',
            mission: [
                {
                    icon: 'user-slash',
                    name: 'daily_kill_player',
                    title: '击杀玩家',
                    description: '击杀够数玩家即可完成任务!',
                    count: 100,
                    completed_count: 45, // 模拟进度
                    levelRequire: 0,
                    reward: {
                        xp: 100,
                        money: 1000,
                    }
                }
            ]
        },
        '周常任务': {
            _index: 5,
            icon: 'calendar-week',
            title: '周常任务',
            description: '完成周常任务, 获得丰厚周常奖励',
            mission: [
                {
                    icon: 'user-slash',
                    name: 'weekly_kill_player',
                    title: '击杀玩家',
                    description: '击杀够数玩家即可完成任务!',
                    count: 100,
                    completed: true, // 模拟已完成状态
                    levelRequire: 0,
                    reward: {
                        xp: 100,
                        money: 1000,
                    }
                }
            ]
        }
    };

    // 显示UI并加载模拟数据
    document.querySelector('.app-container').style.display = 'flex';
    allMissions = mockMissions;
    loadMissionCategories();

    // 根据_index排序获取第一个分类
    const sortedCategories = Object.entries(allMissions).sort((a, b) =>
        a[1]._index - b[1]._index
    );

    if (sortedCategories.length > 0) {
        // 选择排序后的第一个分类
        selectCategory(sortedCategories[0][0]);
    }
}
