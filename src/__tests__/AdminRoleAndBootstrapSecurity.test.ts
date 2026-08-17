import { describe, it, expect, beforeEach } from 'vitest';
import { InMemoryMonitoringRepository } from '../data/repositories/InMemoryMonitoringRepository';

describe('Admin Role & Bootstrap Security Tests', () => {
  let monitoringRepo: InMemoryMonitoringRepository;

  beforeEach(() => {
    monitoringRepo = new InMemoryMonitoringRepository();
    monitoringRepo.resetAll();
  });

  it('1. First Admin Bootstrap: Initial platform setup successfully claims first admin role', async () => {
    expect(await monitoringRepo.getUserRole()).toBe('student');

    const bootstrapRes = await monitoringRepo.claimFirstAdminRole();
    expect(bootstrapRes.success).toBe(true);
    expect(bootstrapRes.message).toContain('bosh administratori sifatida muvaffaqiyatli');

    // Authoritative role is now admin
    expect(await monitoringRepo.getUserRole()).toBe('admin');
  });

  it('2. Bootstrap One-Time Protection: Subsequent bootstrap attempts are strictly rejected', async () => {
    // 1st admin claims role
    const firstRes = await monitoringRepo.claimFirstAdminRole();
    expect(firstRes.success).toBe(true);

    // Another user attempts bootstrap
    const secondRes = await monitoringRepo.claimFirstAdminRole();
    expect(secondRes.success).toBe(false);
    expect(secondRes.message).toContain('allaqachon mavjud');
  });

  it('3. Admin Teacher Code Management: Admin creates and lists secure invitation codes', async () => {
    await monitoringRepo.claimFirstAdminRole();
    expect(await monitoringRepo.getUserRole()).toBe('admin');

    const created = await monitoringRepo.createTeacherInvitation('Toshkent IDUM №1', 5, 30);
    expect(created.plainCode).toMatch(/^USTOZ-[A-Z0-9]{4}-[A-Z0-9]{4}$/);
    expect(created.maxUses).toBe(5);

    const list = await monitoringRepo.listTeacherInvitations();
    expect(list.length).toBeGreaterThan(0);
    const item = list.find((i) => i.id === created.id);
    expect(item?.codePrefix).toContain('****');
  });

  it('4. Admin Code Revocation: Admin revokes invitation code preventing future usage', async () => {
    await monitoringRepo.claimFirstAdminRole();

    const created = await monitoringRepo.createTeacherInvitation('Samarqand Maktabi', 1, 7);
    const revokeRes = await monitoringRepo.revokeTeacherInvitation(created.id);
    expect(revokeRes.success).toBe(true);

    // Redemption of revoked code fails
    const redeemRes = await monitoringRepo.redeemTeacherInvitationCode(created.plainCode);
    expect(redeemRes.success).toBe(false);
  });

  it('5. Role Isolation: Resetting environment isolates admin session', async () => {
    await monitoringRepo.claimFirstAdminRole();
    expect(await monitoringRepo.getUserRole()).toBe('admin');

    monitoringRepo.resetAll();
    expect(await monitoringRepo.getUserRole()).toBe('student');
  });
});
